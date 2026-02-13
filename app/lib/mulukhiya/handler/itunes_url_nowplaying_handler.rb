module Mulukhiya
  class ItunesURLNowplayingHandler < NowplayingHandler
    def create_uri(keyword)
      return ItunesURI.create(keyword)
    end
  end
end
