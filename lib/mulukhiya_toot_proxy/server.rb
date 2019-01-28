require 'json'

module MulukhiyaTootProxy
  class Server < Ginseng::Sinatra
    include Package

    def before_post
      super
      return unless @headers['HTTP_AUTHORIZATION']
      @mastodon = Mastodon.new(
        (@config['/instance_url'] || "https://#{@headers['HTTP_HOST']}"),
        @headers['HTTP_AUTHORIZATION'].split(/\s+/)[1],
      )
    end

    post '/api/v1/statuses' do
      results = []
      Handler.all do |handler|
        handler.mastodon = @mastodon
        handler.exec(params, @headers)
        results.push(handler.result)
      end

      r = @mastodon.toot(params)
      @renderer.message = r.parsed_response
      @renderer.message['results'] = results.join(', ')
      @renderer.message['tags'] = [] if @config['/nowplaying/hashtag']

      @renderer.status = r.code
      Slack.broadcast({params: params, body: @body, headers: @headers}) if 400 <= r.code
      headers({'X-Mulukhiya' => results.join(', ')})
      return @renderer.to_s
    end

    post '/mulukhiya/webhook/:digest' do
      unless webhook = Webhook.create(params[:digest])
        raise Ginseng::NotFoundError, "Resource #{request.path} not found."
      end
      params[:text] ||= params[:body]
      raise Ginseng::RequestError, 'empty message' unless params[:text].present?
      webhook.toot(params[:text])
      @renderer.message = {text: params[:text]}
      return @renderer.to_s
    end

    get '/mulukhiya/webhook/:digest' do
      unless Webhook.create(params[:digest])
        raise Ginseng::NotFoundError, "Resource #{request.path} not found."
      end
      @renderer.message = 'OK'
      return @renderer.to_s
    end
  end
end
