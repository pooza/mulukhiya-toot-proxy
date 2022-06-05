module Mulukhiya
  class YouTubeURLNowplayingHandler < NowplayingHandler
    def disable?
      return true unless YouTubeService.config?
      return super
    end

    def create_uri(keyword)
      return YouTubeURI.parse(keyword)
    end
  end
end
