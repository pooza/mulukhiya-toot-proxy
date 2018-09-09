require 'mulukhiya/spotify_service'
require 'mulukhiya/handler/nowplaying_handler'

module MulukhiyaTootProxy
  class SpotifyNowplayingHandler < NowplayingHandler
    def initialize
      super
      @tracks = {}
      @spotify = SpotifyService.new
    end

    def updatable?(keyword)
      return false unless track = @spotify.search_track(keyword)
      @tracks[keyword] = track
      return true
    end

    def update(keyword, status)
      return unless track = @tracks[keyword]
      status.push(track.external_urls['spotify'])
      track.artists[0..(artists_limit - 1)].each do |artist|
        status.push(artist.external_urls['spotify'])
      end
    end

    private

    def artists_limit
      return @config['application']['spotify']['artists_limit']
    end
  end
end
