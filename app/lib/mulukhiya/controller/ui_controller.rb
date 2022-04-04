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
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.account_timeline?
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.update_status?
      raise Ginseng::NotFoundError, 'Not Found' unless status = status_class[params[:id].to_s]
      raise Ginseng::AuthError, 'Unauthorized' unless status.taggable?
      raise Ginseng::AuthError, 'Unauthorized' unless status.updatable_by?(sns.account)
      @renderer = SlimRenderer.new
      @renderer.template = 'status_detail'
      @renderer[:status] = status.to_h
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
