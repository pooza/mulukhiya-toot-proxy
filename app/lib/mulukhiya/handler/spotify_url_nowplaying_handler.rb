module Mulukhiya
  class SpotifyURLNowplayingHandler < NowplayingHandler
    def disable?
      return super || !SpotifyService.config?
    end

    def create_uri(keyword)
      return unless uri = SpotifyURI.parse(keyword)
      return uri.shorten if uri.shortenable?
      return uri
    end
  end
end
