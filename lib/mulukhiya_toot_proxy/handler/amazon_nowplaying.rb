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

    def update(keyword)
      return unless asin = @asins[keyword]
      push(@service.item_uri(asin).to_s)
    end
  end
end
