module Mulukhiya
  class SongwhipNowplayingHandler < NowplayingHandler
    def initialize(params = {})
      super
      @service = SongwhipService.new
    end

    def updatable?(keyword)
      return false unless uri = create_uri(keyword)
      @uris[keyword] = uri
      return true
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword: keyword)
      return false
    end

    def update(keyword)
      return unless uri = @uris[keyword]
      return unless alt_uri = @service.get(uri)
      push(alt_uri.to_s)
      result.push(source_url: uri.to_s, alt_url: alt_uri.to_s)
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword: keyword)
    end

    def create_uri(keyword)
      return Ginseng::URI.parse(keyword)
    end
  end
end
