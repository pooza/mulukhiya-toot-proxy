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
      @renderer = JsonRenderer.new
      @headers = request.env.select{ |k, v| k.start_with?('HTTP_')}
      @body = request.body.read.to_s
      begin
        @params = JSON.parse(@body)
      rescue JSON::ParserError
        @params = params.clone
      end
      @message = {request: {path: request.path, params: @params}, response: {result: []}}
      if @headers['HTTP_AUTHORIZATION']
        @mastodon = Mastodon.new(
          (@config['local']['instance_url'] || "https://#{@headers['HTTP_HOST']}"),
          @headers['HTTP_AUTHORIZATION'].split(/\s+/)[1],
        )
      end
    end

    after do
      @message[:response][:status] ||= @renderer.status
      if @renderer.status < 400
        @logger.info(@message)
      else
        @logger.error(@message)
      end
      status @renderer.status
      content_type @renderer.type
    end

    get '/about' do
      @message[:response][:message] = Package.full_name
      @renderer.message = @message
      return @renderer.to_s
    end

    post '/api/v1/statuses' do
      Handler.all do |handler|
        handler.mastodon = @mastodon
        handler.exec(@params, @headers)
        @message[:response][:result].push(handler.result)
      end

      r = @mastodon.toot(@params)
      @message.merge!(JSON.parse(r.to_s))
      @message['tags'] = [] if @config['local']['nowplaying']['hashtag']

      @renderer.status = r.code
      Slack.broadcast({params: @params, body: @body, headers: @headers}) if 400 <= r.code
      @renderer.message = @message
      headers({
        'X-Mulukhiya' => @message[:response][:result].join(', '),
      })
      return @renderer.to_s
    end

    not_found do
      @renderer = JsonRenderer.new
      @renderer.status = 404
      @message[:response][:error] = "Resource #{@message[:request][:path]} not found."
      @renderer.message = @message
      return @renderer.to_s
    end

    error do |e|
      @renderer = JsonRenderer.new
      begin
        @renderer.status = e.status
      rescue NoMethodError
        @renderer.status = 500
      end
      @message[:response][:error] = "#{e.class}: #{e.message}"
      @message[:backtrace] = e.backtrace[0..5]
      @message[:error] = e.message
      @renderer.message = @message
      Slack.broadcast(@message)
      return @renderer.to_s
    end
  end
end
