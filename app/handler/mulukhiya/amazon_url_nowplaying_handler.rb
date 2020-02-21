module Mulukhiya
  class AmazonURLNowplayingHandler < NowplayingHandler
    def initialize(params = {})
      super(params)
      @items = {}
      @service = AmazonService.new
    end

    def disable?
      return super || !AmazonService.config?
    end

    def updatable?(keyword)
      return false unless uri = AmazonURI.parse(keyword)
      return false unless uri.item.present?
      @items[keyword] = uri.item
      return true
    rescue => e
      @logger.error(e)
      return false
    end

    def update(keyword)
      return unless item = @items[keyword]
      push(item.dig('ItemInfo', 'Title', 'DisplayValue'))
      return unless contributor = item.dig('ItemInfo', 'ByLineInfo', 'Contributors')&.first
      push(contributor['Name'])
      tags.concat(ArtistParser.new(contributor['Name']).parse)
    end
  end
end
