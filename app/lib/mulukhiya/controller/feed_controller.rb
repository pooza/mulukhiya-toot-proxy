module Mulukhiya
  class FeedController < Controller
    get '/tag/:tag' do
      if controller_class.feed?
        @renderer = TagAtomFeedRenderer.new
        @renderer.tag = params[:tag]
        @renderer.status = 404 unless @renderer.exist?
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    end

    get '/media' do
      if controller_class.media_catalog?
        @renderer = MediaAtomFeedRenderer.new
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    end
  end
end
