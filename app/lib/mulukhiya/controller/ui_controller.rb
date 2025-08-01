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
