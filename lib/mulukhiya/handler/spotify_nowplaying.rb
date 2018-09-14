require 'mulukhiya/spotify_service'
require 'mulukhiya/handler/nowplaying_handler'

module MulukhiyaTootProxy
  class SpotifyNowplayingHandler < NowplayingHandler
    def initialize
      super
      @tracks = {}
      @service = SpotifyService.new
    end

    def updatable?(keyword)
      return false unless track = @service.search_track(keyword)
      @tracks[keyword] = track
      return true
    rescue
      return false
    end

    def update(keyword, status)
      return unless track = @tracks[keyword]
      status.push(track.external_urls['spotify'])
    end
  end
end
