module Mulukhiya
  class YouTubeURLNowplayingHandler < NowplayingHandler
    def disable?
      return super || !YouTubeService.config?
    end

    def create_uri(keyword)
      return YouTubeURI.parse(keyword)
    end
  end
end
