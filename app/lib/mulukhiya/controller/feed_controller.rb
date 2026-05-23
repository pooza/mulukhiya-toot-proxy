module Mulukhiya
  class FeedController < Controller
    get '/tag/:tag' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.feed?
      @renderer = TagFeedRenderer.new
      @renderer.tag = params[:tag]
      @renderer.status = 404 unless @renderer.exist?
      return @renderer.to_s
    rescue => e
      e.log
      @renderer = Ginseng::Web::XMLRenderer.new
      @renderer.status = e.status
      @renderer.message = e.message
      return @renderer.to_s
    end

    get '/media' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.feed?
      @renderer = MediaFeedRenderer.new
      # media_catalog 無効時は MediaFeedRenderer#fetch が空の channel を返す。
      # 404 ではなく 503 を返してフィードの「現在 OFF」状態を明示する (#4343)。
      unless controller_class.media_catalog?
        Logger.new.info(media_catalog: {event: 'disabled_response', endpoint: '/feed/media'})
        @renderer.status = 503
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer = Ginseng::Web::XMLRenderer.new
      @renderer.status = e.status
      @renderer.message = e.message
      return @renderer.to_s
    end

    CustomFeed.all do |feed|
      get feed.path do
        @renderer = feed.renderer
        return @renderer.to_s
      rescue => e
        e.log
        @renderer = Ginseng::Web::XMLRenderer.new
        @renderer.status = e.status
        @renderer.message = e.message
        return @renderer.to_s
      end
    end
  end
end
