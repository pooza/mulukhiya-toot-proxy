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
      @renderer[:oauth_url] = sns.oauth_uri
      @renderer[:infobot_oauth_url] = sns.oauth_uri(:infobot)
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    end

    get '/oauth/callback' do
      raise Ginseng::AuthError, 'Missing state' unless params[:state]
      raise Ginseng::AuthError, 'Missing code' unless params[:code]
      response = sns.auth_with_pkce(params[:code], params[:state])
      raise Ginseng::AuthError, 'Token exchange failed' unless response
      parsed = response.parsed_response
      access_token = parsed['access_token'] || parsed['accessToken']
      raise Ginseng::AuthError, 'No access token in response' unless access_token
      token_crypt = access_token.encrypt
      redirect "/mulukhiya/app/token_complete?token=#{Rack::Utils.escape(token_crypt)}"
    rescue => e
      e.alert
      @renderer = SlimRenderer.new
      @renderer.template = 'token_error'
      @renderer[:error] = e.message
      @renderer.status = e.respond_to?(:status) ? e.status : 500
      return @renderer.to_s
    end

    get '/app/status/:id' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.repost?
      @renderer = SlimRenderer.new
      @renderer.template = 'status_detail'
      @renderer[:id] = params[:id]
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    rescue Ginseng::AuthError
      @renderer.status = 403
    end

    get '/app/status/:id/nowplaying' do
      @renderer = SlimRenderer.new
      @renderer.template = 'status_detail_nowplaying'
      @renderer[:id] = params[:id]
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    rescue Ginseng::AuthError
      @renderer.status = 403
    end

    get '/app/status/:id/poipiku' do
      @renderer = SlimRenderer.new
      @renderer.template = 'status_detail_poipiku'
      @renderer[:id] = params[:id]
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    rescue Ginseng::AuthError
      @renderer.status = 403
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

    def self.media_copyright
      return {
        message: config['/webui/media/copyright/message'],
        url: config['/webui/media/copyright/url'],
      }
    rescue Ginseng::ConfigError
      return nil
    end
  end
end
