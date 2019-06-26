require 'rspotify'

module MulukhiyaTootProxy
  class SpotifyService
    def initialize
      @config = Config.instance
      ENV['ACCEPT_LANGUAGE'] ||= @config['/spotify/language']
      RSpotify.authenticate(@config['/spotify/client_id'], @config['/spotify/client_secret'])
    end

    def search_track(keyword)
      cnt = 1
      tracks = RSpotify::Track.search(keyword)
      return nil if tracks.nil?
      return tracks.first
    rescue => e
      raise Ginseng::GatewayError, "Track not found (#{e.message})" if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def lookup_track(id)
      cnt = 1
      return RSpotify::Track.find(id)
    rescue => e
      raise Ginseng::GatewayError, "Track not found (#{e.message})" if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def lookup_artist(id)
      cnt = 1
      return RSpotify::Artist.find(id)
    rescue => e
      raise Ginseng::GatewayError, "Artist not found (#{e.message})" if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    def create_track_uri(track)
      uri = SpotifyURI.parse(@config['/spotify/urls/track'])
      uri.track_id = track.id
      return nil unless uri&.absolute?
      return uri
    end

    def create_image_uri(track)
      uri = Ginseng::URI.parse(track.album.images.first['url'])
      return nil unless uri&.absolute?
      return uri
    end

    def create_amazon_uri(track)
      amazon = AmazonService.new
      return nil unless asin = amazon.search(create_keyword(track), ['DigitalMusic', 'Music'])
      return amazon.create_item_uri(asin)
    end

    def create_itunes_uri(track)
      itunes = ItunesService.new
      return nil unless track = itunes.search(create_keyword(track), 'music')
      return itunes.create_track_uri(track)
    end

    private

    def create_keyword(track)
      return [track.name].concat(track.artists.map(&:name)).join(' ')
    end

    def retry_limit
      return @config['/spotify/retry_limit']
    end
  end
end
