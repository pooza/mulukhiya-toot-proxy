require 'mulukhiya/spotify_service'
require 'mulukhiya/spotify_uri'
require 'mulukhiya/mastodon'
require 'mulukhiya/handler/nowplaying_handler'

module MulukhiyaTootProxy
  class SpotifyNowplayingHandler < NowplayingHandler
    def initialize
      super
      @results = {}
      @service = SpotifyService.new
    end

    def updatable?(keyword)
      uri = SpotifyURI.parse(keyword)
      if uri.spotify?
        result = {track: uri.track, uri: true}
      elsif track = @service.search_track(keyword)
        result = {track: track}
      end
      return false unless result
      @results[keyword] = result
      return true
    end

    def update(keyword, status)
      return unless result = @results[keyword]
      track = result[:track]
      return status.push(result[:track].external_urls['spotify']) unless result[:uri]
      artists = []
      track.artists.each do |artist|
        artists.push(create_tag(artist.name))
      end
      status.push([track.name, artists.join(' ')].join("\n"))
    end

    private

    def create_tag(name)
      return name unless @config['local']['nowplaying']['hashtag']
      return Mastodon.create_tag(name)
    rescue NoMethodError
      return name
    end

    def artists_limit
      return @config['application']['spotify']['artists_limit']
    end
  end
end
