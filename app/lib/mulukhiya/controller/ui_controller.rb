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
      @renderer[:infobot_oauth_url] = @sns.oauth_uri(:infobot)
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    end

    get '/app/misskey/auth' do
      raise Ginseng::NotFoundError, 'Not Found' unless Environment.misskey_type?
      @renderer = SlimRenderer.new
      @renderer.template = 'misskey_auth'
      errors = MisskeyAuthContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer[:errors] = errors
      else
        response = @sns.auth(params[:token])
        @sns.token = @sns.create_access_token(response.parsed_response['accessToken'])
        @renderer[:access_token_crypt] = @sns.token.encrypt
      end
      return @renderer.to_s
    rescue => e
      e = Ginseng::Error.create(e)
      @renderer = Ginseng::Web::JSONRenderer.new
      @renderer.status = e.status
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
      return params[:token].decrypt
    rescue
      return params[:token]
    end
  end
end
