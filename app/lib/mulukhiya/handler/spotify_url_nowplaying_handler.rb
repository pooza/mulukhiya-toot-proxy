module Mulukhiya
  class SpotifyURLNowplayingHandler < NowplayingHandler
    def disable?
      return false unless SpotifyService.config?
      return super
    end

    def create_uri(keyword)
      return SpotifyURI.parse(keyword)
    end
  end
end
