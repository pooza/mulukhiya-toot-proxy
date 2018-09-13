require 'rspotify'
require 'mulukhiya/config'
require 'mulukhiya/spotify_uri'
require 'mulukhiya/external_service_error'

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
    rescue => e
      raise ExternalServiceError, e.message
    end

    def lookup_track(id)
      return RSpotify::Track.find(id)
    rescue => e
      raise ExternalServiceError, e.message
    end

    def lookup_artist(id)
      return RSpotify::Artist.find(id)
    rescue => e
      raise ExternalServiceError, e.message
    end

    def track_url(id)
      return item_uri(id)
    end

    def track_uri(id)
      uri = SpotifyURI.parse(@config['application']['spotify']['url'])
      uri.track_id = id
      return uri
    rescue => e
      raise ExternalServiceError, e.message
    end

    private

    def retry_limit
      return @config['application']['spotify']['retry_limit']
    end
  end
end
