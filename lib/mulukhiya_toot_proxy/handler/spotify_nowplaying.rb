module MulukhiyaTootProxy
  class SpotifyNowplayingHandler < NowplayingHandler
    def initialize
      super
      @tracks = {}
      @service = SpotifyService.new
    end

    def updatable?(keyword)
      return true if @tracks[keyword] = @service.search_track(keyword)
      return false
    rescue
      return false
    end

    def update(keyword)
      return unless track = @tracks[keyword]
      push(track.external_urls['spotify'])
    end
  end
end
