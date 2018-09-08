require 'rspotify'
require 'mulukhiya/config'
require 'mulukhiya/external_service_error'

module MulukhiyaTootProxy
  class Spotify
    def initialize
      @config = Config.instance
      RSpotify.authenticate(
        @config['local']['spotify']['client_id'],
        @config['local']['spotify']['client_secret'],
      )
    end

    def search_track(keyword)
      cnt = 1
      tracks = RSpotify::Track.search(keyword)
      return nil if tracks.nil?
      return tracks.first
    rescue => e
      raise ExternalServiceError, e.message if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def retry_limit
      return @config['application']['spotify']['retry_limit']
    end
  end
end
