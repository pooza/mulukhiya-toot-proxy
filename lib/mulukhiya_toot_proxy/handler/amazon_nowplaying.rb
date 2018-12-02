module MulukhiyaTootProxy
  class AmazonNowplayingHandler < NowplayingHandler
    def initialize
      super
      @asins = {}
      @service = AmazonService.new
    end

    def updatable?(keyword)
      return true if @asins[keyword] = @service.search(keyword, ['DigitalMusic', 'Music'])
      return false
    end

    def update(keyword, status)
      return unless asin = @asins[keyword]
      status.push(@service.item_uri(asin).to_s)
    end
  end
end
