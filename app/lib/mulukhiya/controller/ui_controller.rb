module Mulukhiya
  class UIController < Controller
    get '/' do
      @renderer = SlimRenderer.new
      @renderer.template = 'home'
      return @renderer.to_s
    end

    get '/app/:page' do
      @renderer = SlimRenderer.new
      @renderer.template = params[:page]
      @renderer[:oauth_url] = @sns.oauth_uri
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    end

    post '/app/mastodon/auth' do
      @renderer = SlimRenderer.new
      errors = MastodonAuthContract.new.exec(params)
      if errors.present?
        @renderer.template = 'auth'
        @renderer[:errors] = errors
        @renderer[:oauth_url] = @sns.oauth_uri
        @renderer.status = 422
      else
        @renderer.template = 'auth_result'
        response = @sns.auth(params[:code])
        if response.code == 200
          @sns.token = response.parsed_response['access_token']
          @sns.account.config.webhook_token = @sns.token
          @renderer[:hook_url] = @sns.account.webhook&.uri
        end
        @renderer[:status] = response.code
        @renderer[:result] = response.parsed_response
        @renderer.status = response.code
      end
      return @renderer.to_s
    rescue => e
      @renderer = Ginseng::Web::JSONRenderer.new
      @renderer.status = 403
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/app/misskey/auth' do
      @renderer = SlimRenderer.new
      errors = MisskeyAuthContract.new.exec(params)
      if errors.present?
        @renderer.template = 'auth'
        @renderer[:errors] = errors
        @renderer[:oauth_url] = @sns.oauth_uri
        @renderer.status = 422
      else
        @renderer.template = 'auth_result'
        response = @sns.auth(params[:token])
        if response.code == 200
          @sns.token = @sns.create_access_token(r.parsed_response['accessToken'])
          @sns.account.config.webhook_token = @sns.token
          @renderer[:hook_url] = @sns.account.webhook&.uri
        end
        @renderer[:status] = response.code
        @renderer[:result] = {access_token: @sns.token}
        @renderer.status = response.code
      end
      return @renderer.to_s
    rescue => e
      @renderer = Ginseng::Web::JSONRenderer.new
      @renderer.status = 403
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/media/:media' do
      @renderer = StaticMediaRenderer.new
      @renderer.name = params[:media]
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    end

    get '/style/:style' do
      @renderer = CSSRenderer.new
      @renderer.template = params[:style]
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    end

    get '/script/:script' do
      @renderer = ScriptRenderer.new
      @renderer.name = params[:script]
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    end

    def token
      return Crypt.new.decrypt(params[:token]) if params[:token]
    end
  end
end
