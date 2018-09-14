require 'rspotify'
require 'mulukhiya/config'
require 'mulukhiya/spotify_uri'
require 'mulukhiya/amazon_service'
require 'mulukhiya/external_service_error'

module MulukhiyaTootProxy
  class SpotifyService
    def initialize
      @config = Config.instance
      @amazon = AmazonService.new
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
      raise ExternalServiceError, "曲が見つかりません。 #{e.message}" if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def lookup_track(id)
      cnt = 1
      return RSpotify::Track.find(id)
    rescue => e
      raise ExternalServiceError, "曲が見つかりません。 #{e.message}" if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def lookup_artist(id)
      cnt = 1
      return RSpotify::Artist.find(id)
    rescue => e
      raise ExternalServiceError, "アーティストが見つかりません。 #{e.message}" if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def track_url(id)
      return track_uri(id)
    end

    def track_uri(id)
      uri = SpotifyURI.parse(@config['application']['spotify']['url'])
      uri.track_id = id
      return uri
    end

    def amazon_url(track)
      return amazon_uri(track)
    end

    def amazon_uri(track)
      # keyword = "#{track.name} #{track.artists.first.name}"
      keyword = track.name
      asin = @amazon.search(keyword, 'DigitalMusic')
      asin ||= @amazon.search(keyword, 'Music')
      return nil unless asin
      return @amazon.item_uri(asin)
    end

    private

    def retry_limit
      return @config['application']['spotify']['retry_limit'] || 5
    end
  end
end
