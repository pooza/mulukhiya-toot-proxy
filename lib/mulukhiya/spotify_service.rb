require 'rspotify'
require 'mulukhiya/config'
require 'mulukhiya/spotify_uri'

module MulukhiyaTootProxy
  class SpotifyService
    def initialize
      @config = Config.instance
      RSpotify.authenticate(
        @config['local']['spotify']['client_id'],
        @config['local']['spotify']['client_secret'],
      )
    end

    def search_track(keyword)
      tracks = RSpotify::Track.search(keyword)
      return nil if tracks.nil?
      return tracks.first
    end

    def lookup_track(id)
      return RSpotify::Track.find(id)
    end

    def lookup_artist(id)
      return RSpotify::Artist.find(id)
    end

    def track_url(id)
      return item_uri(id)
    end

    def track_uri(id)
      uri = SpotifyURI.parse(@config['application']['spotify']['url'])
      uri.path = "/track/#{id}"
      return uri
    end

    def retry_limit
      return @config['application']['spotify']['retry_limit']
    end
  end
end
