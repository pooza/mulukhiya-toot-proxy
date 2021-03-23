module Mulukhiya
  class AmazonURLNowplayingHandler < NowplayingHandler
    def disable?
      return false unless AmazonService.config?
      return super
    end

    def create_uri(keyword)
      return AmazonURI.parse(keyword)
    end
  end
end
