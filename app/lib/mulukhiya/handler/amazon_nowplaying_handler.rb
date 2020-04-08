module Mulukhiya
  class AmazonNowplayingHandler < NowplayingHandler
    def initialize(params = {})
      super(params)
      @asins = {}
      @service = AmazonService.new
    end

    def disable?
      return super || !AmazonService.config?
    end

    def updatable?(keyword)
      return true if @asins[keyword] = @service.search(keyword, ['DigitalMusic', 'Music'])
      return false
    rescue => e
      errors.push(class: e.class.to_s, message: e.message)
      return false
    end

    def update(keyword)
      return unless asin = @asins[keyword]
      push(@service.create_item_uri(asin).to_s)
    end
  end
end
