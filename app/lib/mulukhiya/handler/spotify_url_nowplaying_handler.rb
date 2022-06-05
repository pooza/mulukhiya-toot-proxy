module Mulukhiya
  class SpotifyURLNowplayingHandler < NowplayingHandler
    def disable?
      return true unless SpotifyService.config?
      return super
    end

    def create_uri(keyword)
      return SpotifyURI.parse(keyword)
    end
  end
end
