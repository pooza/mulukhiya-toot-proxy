module Mulukhiya
  class SpotifyService
    include Package

    def initialize
      ENV['ACCEPT_LANGUAGE'] ||= config['/spotify/language']
      RSpotify.authenticate(SpotifyService.client_id, SpotifyService.client_secret)
    end

    def search_track(keyword)
      cnt ||= 0
      return nil unless self.class.config?
      return nil unless tracks = RSpotify::Track.search(keyword)
      return tracks.first
    rescue => e
      cnt += 1
      logger.error(error: e, count: cnt)
      raise Ginseng::GatewayError, e.message, e.backtrace unless cnt < retry_limit
      sleep(config['/spotify/retry/seconds'])
      retry
    end

    def lookup_album(id)
      cnt ||= 0
      return nil unless self.class.config?
      return RSpotify::Album.find(id)
    rescue => e
      cnt += 1
      logger.error(error: e, count: cnt)
      raise Ginseng::GatewayError, e.message, e.backtrace unless cnt < retry_limit
      sleep(config['/spotify/retry/seconds'])
      retry
    end

    def lookup_track(id)
      cnt ||= 0
      return nil unless self.class.config?
      return RSpotify::Track.find(id)
    rescue => e
      cnt += 1
      logger.error(error: e, count: cnt)
      raise Ginseng::GatewayError, e.message, e.backtrace unless cnt < retry_limit
      sleep(config['/spotify/retry/seconds'])
      retry
    end

    def lookup_artist(id)
      cnt ||= 0
      return nil unless self.class.config?
      return RSpotify::Artist.find(id)
    rescue => e
      cnt += 1
      logger.error(error: e, count: cnt)
      raise Ginseng::GatewayError, e.message, e.backtrace unless cnt < retry_limit
      sleep(config['/spotify/retry/seconds'])
      retry
    end

    def create_track_uri(track)
      uri = SpotifyURI.parse(config['/spotify/urls/track'])
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

    def self.client_id
      return config['/spotify/client/id'] rescue nil
    end

    def self.client_secret
      return config['/spotify/client/secret'].decrypt
    rescue Ginseng::ConfigError
      return nil
    rescue
      return config['/spotify/client/secret']
    end

    def self.config?
      return false unless client_id
      return false unless client_secret
      SpotifyService.new
      return true
    rescue => e
      logger.error(error: e)
      return false
    end

    private

    def create_keyword(track)
      return [track.name].concat(track.artists.map(&:name)).join(' ')
    end

    def retry_limit
      return config['/http/retry/limit']
    end
  end
end
