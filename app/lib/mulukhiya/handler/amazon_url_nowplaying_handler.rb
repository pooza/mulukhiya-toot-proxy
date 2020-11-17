module Mulukhiya
  class AmazonURLNowplayingHandler < NowplayingHandler
    def disable?
      return super || !AmazonService.config?
    end

    def create_uri(keyword)
      return AmazonURI.parse(keyword)
    end
  end
end
