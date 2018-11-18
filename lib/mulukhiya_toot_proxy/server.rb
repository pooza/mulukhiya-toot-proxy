require 'sinatra'
require 'json'

module MulukhiyaTootProxy
  class Server < Sinatra::Base
    def initialize
      super
      @config = Config.instance
      @logger = Logger.new
      @logger.info({
        message: 'starting...',
        server: {port: @config['thin']['port']},
        version: Package.version,
      })
    end

    before do
      @logger.info({request: {path: request.path, params: @params}})
      @renderer = JSONRenderer.new
      @headers = request.env.select{ |k, v| k.start_with?('HTTP_')}
      if @headers['HTTP_AUTHORIZATION'] && (request.request_method == 'POST')
        @body = request.body.read.to_s
        begin
          @params = JSON.parse(@body)
        rescue JSON::ParserError
          @params = params.clone
        end
        @mastodon = Mastodon.new(
          (@config['local']['instance_url'] || "https://#{@headers['HTTP_HOST']}"),
          @headers['HTTP_AUTHORIZATION'].split(/\s+/)[1],
        )
      end
    end

    after do
      status @renderer.status
      content_type @renderer.type
    end

    get '/about' do
      @renderer.message = Package.full_name
      return @renderer.to_s
    end

    post '/api/v1/statuses' do
      results = []
      Handler.all do |handler|
        handler.mastodon = @mastodon
        handler.exec(@params, @headers)
        results.push(handler.result)
      end

      r = @mastodon.toot(@params)
      @renderer.message = JSON.parse(r.to_s)
      @renderer.message['results'] = results.join(', ')
      @renderer.message['tags'] = [] if @config['local']['nowplaying']['hashtag']

      @renderer.status = r.code
      Slack.broadcast({params: @params, body: @body, headers: @headers}) if 400 <= r.code
      headers({
        'X-Mulukhiya' => results.join(', '),
      })
      return @renderer.to_s
    end

    not_found do
      @renderer = JSONRenderer.new
      @renderer.status = 404
      @renderer.message = NotFoundError.new("Resource #{request.path} not found.").to_h
      return @renderer.to_s
    end

    error do |e|
      e = Error.create(e)
      @renderer = JSONRenderer.new
      @renderer.status = e.status
      @renderer.message = e.to_h.delete_if{ |k, v| k == :backtrace}
      Slack.broadcast(e.to_h)
      @logger.error(e.to_h)
      return @renderer.to_s
    end
  end
end
