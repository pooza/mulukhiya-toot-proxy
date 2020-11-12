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
    rescue Ginseng::RenderError
      @renderer.status = 404
    end

    get '/style/:style' do
      @renderer = CSSRenderer.new
      @renderer.template = params[:style]
      return @renderer.to_s
    rescue Ginseng::RenderError
      @renderer.status = 404
    end

    get '/script/:script' do
      @renderer = ScriptRenderer.new
      @renderer.file = params[:script]
      return @renderer.to_s
    rescue Ginseng::RenderError
      @renderer.status = 404
    end

    private

    def token
      return Crypt.new.decrypt(params[:token]) if params[:token]
    end
  end
end
