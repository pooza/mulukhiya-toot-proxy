module Mulukhiya
  class SpotifyURLNowplayingHandler < NowplayingHandler
    def toggleable?
      return false unless SpotifyService.config?
      return super
    end

    def create_uri(keyword)
      return SpotifyURI.parse(keyword)
    end
  end
end
