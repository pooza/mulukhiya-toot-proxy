require 'mulukhiya/amazon_service'
require 'mulukhiya/handler/nowplaying_handler'

module MulukhiyaTootProxy
  class AmazonNowplayingHandler < NowplayingHandler
    def initialize
      super
      @asins = {}
      @service = AmazonService.new
    end

    def updatable?(keyword)
      asin = @service.search(keyword, 'DigitalMusic')
      asin ||= @service.search(keyword, 'Music')
      return false unless asin
      @asins[keyword] = asin
      return true
    end

    def update(keyword, status)
      return unless asin = @asins[keyword]
      status.push(@service.item_uri(asin).to_s)
    end
  end
end
