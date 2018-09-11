require 'mulukhiya/spotify_service'
require 'mulukhiya/spotify_uri'
require 'mulukhiya/handler/nowplaying_handler'

module MulukhiyaTootProxy
  class SpotifyNowplayingHandler < NowplayingHandler
    def initialize
      super
      @results = {}
      @spotify = SpotifyService.new
    end

    def updatable?(keyword)
      uri = SpotifyURI.parse(keyword)
      if uri.absolute?
        track = {track: uri.track, uri: true}
      else
        track = {track: @spotify.search_track(keyword)}
      end
      return false unless track
      @results[keyword] = track
      return true
    end

    def update(keyword, status)
      if result = @results[keyword]
        track = result[:track]
        if result[:uri]
          info = [track.name]
          track.artists.each do |artist|
            info.push("##{artist.name.tr(' ', '_')}")
          end
          status.push(info.join(' '))
        else
          status.push(result[:track].external_urls['spotify'])
        end
      end
    end

    private

    def artists_limit
      return @config['application']['spotify']['artists_limit']
    end
  end
end
