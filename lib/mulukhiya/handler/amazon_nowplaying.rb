require 'mulukhiya/amazon_service'
require 'mulukhiya/handler/nowplaying_handler'

module MulukhiyaTootProxy
  class AmazonNowplayingHandler < NowplayingHandler
    def initialize
      super
      @asins = {}
      @amazon = AmazonService.new
    end

    def updatable?(keyword)
      asin = (@amazon.search(keyword, 'DigitalMusic') || @amazon.search(keyword, 'Music'))
      return false unless asin
      @asins[keyword] = asin
      return true
    end

    def update(keyword, status)
      return unless asin = @asins[keyword]
      status.push(@amazon.item_uri(asin).to_s)
    end
  end
end
