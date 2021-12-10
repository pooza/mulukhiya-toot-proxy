module Mulukhiya
  class ItunesNowplayingHandler < NowplayingHandler
    def initialize(params = {})
      super
      @service = ItunesService.new
    end

    def updatable?(keyword)
      return false if Ginseng::URI.parse(keyword)&.absolute?
      return true if @tracks[keyword] = @service.search(keyword, 'music')
      return false
    rescue Addressable::URI::InvalidURIError
      return false
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword: keyword)
      return false
    end

    def update(keyword)
      return unless track = @tracks[keyword]
      push(track['trackViewUrl'])
      reporter.temp[:track_uris].push(track['trackViewUrl'])
      result.push(keyword: keyword)
    end
  end
end
