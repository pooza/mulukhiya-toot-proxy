module Mulukhiya
  class SpotifyURLNowplayingHandler < NowplayingHandler
    def disable?
      return super || !SpotifyService.config?
    end

    def create_uri(keyword)
      return SpotifyURI.parse(keyword)
    end
  end
end
