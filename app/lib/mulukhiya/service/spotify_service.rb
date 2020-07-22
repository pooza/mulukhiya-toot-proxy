require 'rspotify'

module Mulukhiya
  class SpotifyService
    def initialize
      @config = Config.instance
      @logger = Logger.new
      ENV['ACCEPT_LANGUAGE'] ||= @config['/spotify/language']
      RSpotify.authenticate(@config['/spotify/client_id'], @config['/spotify/client_secret'])
    end

    def search_track(keyword)
      return nil unless SpotifyService.config?
      tracks = RSpotify::Track.search(keyword)
      return nil if tracks.nil?
      return tracks.first
    end

    def lookup_album(id)
      return nil unless SpotifyService.config?
      return RSpotify::Album.find(id)
    end

    def lookup_track(id)
      return nil unless SpotifyService.config?
      return RSpotify::Track.find(id)
    end

    def lookup_artist(id)
      return nil unless SpotifyService.config?
      return RSpotify::Artist.find(id)
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
      config['/spotify/client_id']
      config['/spotify/client_secret']
      return true
    rescue Ginseng::ConfigError
      return false
    end

    private

    def create_keyword(track)
      return [track.name].concat(track.artists.map(&:name)).join(' ')
    end
  end
end
