module Mulukhiya
  class SpotifyNowplayingHandler < NowplayingHandler
    def initialize(params = {})
      super
      @service = SpotifyService.new
    end

    def disable?
      return super || !SpotifyService.config?
    end

    def updatable?(keyword)
      return false if Ginseng::URI.parse(keyword)&.absolute?
      return true if @tracks[keyword] = @service.search_track(keyword)
      return false
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword: keyword)
      return false
    end

    def update(keyword)
      return unless track = @tracks[keyword]
      push(track.external_urls['spotify'])
      result.push(keyword: keyword)
    end
  end
end
