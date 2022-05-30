module Mulukhiya
  class YouTubeURLNowplayingHandler < NowplayingHandler
    def toggleable?
      return false unless YouTubeService.config?
      return super
    end

    def create_uri(keyword)
      return YouTubeURI.parse(keyword)
    end
  end
end
