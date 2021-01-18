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

    get '/app/misskey/auth' do
      raise "Invalid controller '#{Environment.controller_name}'" unless Environment.misskey_type?
      @renderer = SlimRenderer.new
      errors = MisskeyAuthContract.new.exec(params)
      if errors.present?
        @renderer.template = 'token'
        @renderer[:errors] = errors
        @renderer[:oauth_url] = @sns.oauth_uri
        @renderer.status = 422
      else
        @renderer.template = 'auth_result'
        response = @sns.auth(params[:token])
        @sns.token = @sns.create_access_token(response.parsed_response['accessToken'])
        @sns.account.user_config.webhook_token = @sns.token
        @renderer[:hook_url] = @sns.account.webhook&.uri
        @renderer[:status] = response.code
        @renderer[:result] = {access_token: @sns.token}
      end
      return @renderer.to_s
    rescue => e
      @renderer = Ginseng::Web::JSONRenderer.new
      @renderer.status = 403
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/media/:name' do
      @renderer = StaticMediaRenderer.new
      @renderer.name = params[:name]
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    end

    get '/style/:name' do
      @renderer = CSSRenderer.new
      @renderer.template = params[:name]
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    end

    get '/script/:name' do
      @renderer = ScriptRenderer.new
      @renderer.name = params[:name]
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    end

    def token
      return params[:token].decrypt if params[:token]
      return nil
    end
  end
end
