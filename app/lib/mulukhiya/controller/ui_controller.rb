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
      return nil unless config['/webui/media/copyright/message']
      return nil unless config['/webui/media/copyright/url']
      return {
        message: config['/webui/media/copyright/message'],
        url: config['/webui/media/copyright/url'],
      }
    end
  end
end
