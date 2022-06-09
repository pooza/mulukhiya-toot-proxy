module Mulukhiya
  class ItunesNowplayingHandler < NowplayingHandler
    def initialize(params = {})
      super
      @service = ItunesService.new
    end

    def updatable?(keyword)
      return false if Ginseng::URI.parse(keyword)&.absolute?
      return false unless @tracks[keyword] = @service.search(keyword, 'music')
      return true
    rescue Addressable::URI::InvalidURIError
      return false
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword:)
      return false
    end

    def update(keyword)
      return unless track = @tracks[keyword]
      push(track['trackViewUrl'])
      reporter.temp[:track_uris].push(track['trackViewUrl'])
      result.push(keyword:)
    end
  end
end
