module MulukhiyaTootProxy
  class SpotifyNowplayingHandler < NowplayingHandler
    def initialize(params = {})
      super(params)
      @tracks = {}
      @service = SpotifyService.new
    end

    def disable?
      return super || !SpotifyService.config?
    end

    def updatable?(keyword)
      return true if @tracks[keyword] = @service.search_track(keyword)
      return false
    rescue => e
      @logger.error(e)
      return false
    end

    def update(keyword)
      return unless track = @tracks[keyword]
      push(track.external_urls['spotify'])
    end
  end
end
