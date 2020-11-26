module Mulukhiya
  class SpotifyService
    def initialize
      @config = Config.instance
      @logger = Logger.new
      ENV['ACCEPT_LANGUAGE'] ||= @config['/spotify/language']
      RSpotify.authenticate(@config['/spotify/client/id'], @config['/spotify/client/secret'])
    end

    def search_track(keyword)
      cnt ||= 0
      return nil unless SpotifyService.config?
      return nil unless tracks = RSpotify::Track.search(keyword)
      return tracks.first
    rescue => e
      cnt += 1
      @logger.error(error: e, count: cnt)
      raise Ginseng::GatewayError, e.message, e.backtrace unless cnt < retry_limit
      sleep(1)
      retry
    end

    def lookup_album(id)
      cnt ||= 0
      return nil unless SpotifyService.config?
      return RSpotify::Album.find(id)
    rescue => e
      cnt += 1
      @logger.error(error: e, count: cnt)
      raise Ginseng::GatewayError, e.message, e.backtrace unless cnt < retry_limit
      sleep(1)
      retry
    end

    def lookup_track(id)
      cnt ||= 0
      return nil unless SpotifyService.config?
      return RSpotify::Track.find(id)
    rescue => e
      cnt += 1
      @logger.error(error: e, count: cnt)
      raise Ginseng::GatewayError, e.message, e.backtrace unless cnt < retry_limit
      sleep(1)
      retry
    end

    def lookup_artist(id)
      cnt ||= 0
      return nil unless SpotifyService.config?
      return RSpotify::Artist.find(id)
    rescue => e
      cnt += 1
      @logger.error(error: e, count: cnt)
      raise Ginseng::GatewayError, e.message, e.backtrace unless cnt < retry_limit
      sleep(1)
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

    def self.config?
      config = Config.instance
      config['/spotify/client/id']
      config['/spotify/client/secret']
      SpotifyService.new
      return true
    rescue
      return false
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
