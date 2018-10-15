require 'rspotify'
require 'addressable/uri'
require 'mulukhiya/config'
require 'mulukhiya/uri/spotify'
require 'mulukhiya/amazon_service'
require 'mulukhiya/error/external_service'

module MulukhiyaTootProxy
  class SpotifyService
    def initialize
      @config = Config.instance
      ENV['ACCEPT_LANGUAGE'] ||= @config['local']['spotify']['language']
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

    def track_uri(id)
      uri = SpotifyURI.parse(@config['application']['spotify']['url'])
      uri.track_id = id
      return uri
    end

    def image_uri(track)
      return Addressable::URI.parse(track.album.images.first['url'])
    rescue
      return nil
    end

    def amazon_uri(track)
      keyword = [track.name]
      track.artists.each do |artist|
        keyword.push(artist.name)
      end
      keyword = keyword.join(' ')
      amazon = AmazonService.new
      return nil unless asin = amazon.search(keyword, ['DigitalMusic', 'Music'])
      return amazon.item_uri(asin)
    end

    private

    def retry_limit
      return @config['application']['spotify']['retry_limit'] || 5
    end
  end
end
