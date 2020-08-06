module Mulukhiya
  class AmazonURLNowplayingHandler < NowplayingHandler
    def disable?
      return super || !AmazonService.config?
    end

    def updatable?(keyword)
      return false unless uri = AmazonURI.parse(keyword)
      return false unless uri.item
      @uris[keyword] = uri
      return true
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword: keyword)
      return false
    end

    def update(keyword)
      return unless uri = @uris[keyword]
      push(uri.item.dig('ItemInfo', 'Title', 'DisplayValue'))
      return unless contributors = uri.item.dig('ItemInfo', 'ByLineInfo', 'Contributors')
      push(contributors.map {|v| v['Name']}.join(', '))
      tags.concat(ArtistParser.new(contributors.map {|v| v['Name']}.join('、')).parse)
      result.push(url: uri.to_s)
    end
  end
end
