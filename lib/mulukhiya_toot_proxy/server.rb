module MulukhiyaTootProxy
  class Server < Ginseng::Web::Sinatra
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
      results = ResultContainer.new
      Handler.exec_all(:pre_toot, params, {
        results: results,
        mastodon: @mastodon,
        headers: @headers,
      })
      results.response = @mastodon.toot(params)
      Handler.exec_all(:post_toot, params, {
        results: results,
        mastodon: @mastodon,
      })
      @renderer.message = results.response.parsed_response
      @renderer.message['results'] = results.summary
      @renderer.message['tags']&.keep_if{|v| tags.include?(v['name'])}
      @renderer.status = results.response.code
      headers({'X-Mulukhiya' => results.summary})
      return @renderer.to_s
    end

    post '/api/v1/statuses/:id/favourite' do
      results = ResultContainer.new
      results.response = @mastodon.fav(params[:id])
      Handler.exec_all(:post_fav, params, {results: results})
      @renderer.message = results.response.parsed_response
      @renderer.message['results'] = results.summary
      @renderer.status = results.response.code
      headers({'X-Mulukhiya' => results.summary})
      return @renderer.to_s
    end

    post '/api/v1/statuses/:id/reblog' do
      results = ResultContainer.new
      results.response = @mastodon.boost(params[:id])
      Handler.exec_all(:post_boost, params, {results: results})
      @renderer.message = results.response.parsed_response
      @renderer.message['results'] = results.summary
      @renderer.status = results.response.code
      headers({'X-Mulukhiya' => results.summary})
      return @renderer.to_s
    end

    post '/mulukhiya/webhook/:digest' do
      if webhook = Webhook.create(params[:digest])
        raise Ginseng::RequestError, 'empty message' unless params[:text].present?
        results = webhook.toot(params)
        @renderer.message = results.response.parsed_response
        @renderer.message['results'] = results.summary
        @renderer.status = results.response.code
        headers({'X-Mulukhiya' => results.summary})
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    end

    get '/mulukhiya/webhook/:digest' do
      if Webhook.create(params[:digest])
        @renderer.message = {message: 'OK'}
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    end

    get '/mulukhiya/app/auth' do
      @renderer = HTMLRenderer.new
      @renderer.template = 'app_auth'
      @renderer['oauth_url'] = Mastodon.new.oauth_uri
      return @renderer.to_s
    end

    post '/mulukhiya/app/auth' do
      r = Mastodon.new.auth(params[:code])
      @renderer = HTMLRenderer.new
      @renderer.template = 'app_auth_result'
      @renderer['status'] = r.code
      @renderer['result'] = r.parsed_response
      @renderer.status = r.code
      return @renderer.to_s
    end

    get '/mulukhiya/style/:style' do
      @renderer = CSSRenderer.new
      @renderer.template = params[:style]
      return @renderer.to_s
    rescue Ginseng::RenderError
      @renderer.status = 404
    end

    not_found do
      @renderer = Ginseng::Web::JSONRenderer.new
      @renderer.status = 404
      @renderer.message = Ginseng::NotFoundError.new("Resource #{request.path} not found.").to_h
      return @renderer.to_s
    end

    error do |e|
      e = Ginseng::Error.create(e)
      e.package = Package.full_name
      @renderer = Ginseng::Web::JSONRenderer.new
      @renderer.status = e.status
      @renderer.message = e.to_h.delete_if{|k, v| k == :backtrace}
      @renderer.message['error'] = e.message
      Slack.broadcast(e)
      @logger.error(e)
      return @renderer.to_s
    end
  end
end
