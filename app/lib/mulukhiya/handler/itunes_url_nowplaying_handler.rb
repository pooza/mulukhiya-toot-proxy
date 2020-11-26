module Mulukhiya
  class ItunesURLNowplayingHandler < NowplayingHandler
    def create_uri(keyword)
      return ItunesURI.parse(keyword)
    end
  end
end
