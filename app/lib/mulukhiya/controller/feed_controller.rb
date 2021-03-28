module Mulukhiya
  class FeedController < Controller
    get '/tag/:tag' do
      raise Ginseng::AuthError, 'Unauthorized' unless controller_class.feed?
      @renderer = TagFeedRenderer.new
      @renderer.tag = params[:tag]
      @renderer.status = 404 unless @renderer.exist?
      return @renderer.to_s
    rescue => e
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/media' do
      raise Ginseng::AuthError, 'Unauthorized' unless controller_class.feed?
      raise Ginseng::AuthError, 'Unauthorized' unless controller_class.media_catalog?
      @renderer = MediaFeedRenderer.new
      return @renderer.to_s
    rescue => e
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end
  end
end
