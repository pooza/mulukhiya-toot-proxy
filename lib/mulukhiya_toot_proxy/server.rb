module MulukhiyaTootProxy
  class Server < Ginseng::Sinatra
    include Package
    set :root, Environment.dir

    def before_post
      super
      return unless @headers['HTTP_AUTHORIZATION']
      @mastodon = Mastodon.new
      @mastodon.token = @headers['HTTP_AUTHORIZATION'].split(/\s+/)[1]
    end

    post '/api/v1/statuses' do
      tags = TagContainer.scan(params[:status])
      results = Handler.exec_all(params, @headers, {mastodon: @mastodon})
      r = @mastodon.toot(params)
      @renderer.message = r.parsed_response
      @renderer.message['results'] = results.summary
      @renderer.message['tags']&.keep_if{|v| tags.include?(v['name'])}
      @renderer.status = r.code
      headers({'X-Mulukhiya' => results.summary})
      return @renderer.to_s
    end

    post '/mulukhiya/webhook/:digest' do
      unless webhook = Webhook.create(params[:digest])
        raise Ginseng::NotFoundError, "Resource #{request.path} not found."
      end
      raise Ginseng::RequestError, 'empty message' unless params[:text].present?
      r = webhook.toot(params)
      @renderer.message = r.parsed_response
      @renderer.message['results'] = webhook.results.summary
      @renderer.status = r.code
      return @renderer.to_s
    end

    get '/mulukhiya/app/auth' do
      @mastodon = Mastodon.new
      @renderer = HTMLRenderer.new
      @renderer.template = 'app_auth'
      @renderer['oauth_url'] = @mastodon.oauth_uri
      return @renderer.to_s
    end

    post '/mulukhiya/app/auth' do
      @mastodon = Mastodon.new
      r = @mastodon.auth(params[:code])
      @renderer = HTMLRenderer.new
      @renderer.template = 'app_auth_result'
      @renderer['status'] = r.code
      @renderer['token'] = r.parsed_response['access_token']
      @renderer.status = r.code
      return @renderer.to_s
    end

    get '/mulukhiya/webhook/:digest' do
      unless Webhook.create(params[:digest])
        raise Ginseng::NotFoundError, "Resource #{request.path} not found."
      end
      @renderer.message = {message: 'OK'}
      return @renderer.to_s
    end

    get '/mulukhiya/style/default.css' do
      @renderer = CSSRenderer.new
      @renderer.template = 'default'
      return @renderer.to_s
    end

    not_found do
      @renderer.status = 404
      @renderer.message = Ginseng::NotFoundError.new("Resource #{request.path} not found.").to_h
      return @renderer.to_s
    end

    error do |e|
      e = Ginseng::Error.create(e)
      e.package = Package.full_name
      @renderer.status = e.status
      @renderer.message = e.to_h.delete_if{|k, v| k == :backtrace}
      @renderer.message['error'] = e.message
      Slack.broadcast(e)
      @logger.error(e)
      return @renderer.to_s
    end
  end
end
