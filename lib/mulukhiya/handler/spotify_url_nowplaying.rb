require 'mulukhiya/spotify_service'
require 'mulukhiya/spotify_uri'
require 'mulukhiya/mastodon'
require 'mulukhiya/handler/nowplaying_handler'

module MulukhiyaTootProxy
  class SpotifyUrlNowplayingHandler < NowplayingHandler
    def initialize
      super
      @tracks = {}
      @service = SpotifyService.new
    end

    def updatable?(keyword)
      return false unless uri = SpotifyURI.parse(keyword)
      return false unless uri.spotify?
      return false unless uri.track.present?
      @tracks[keyword] = uri.track
      return true
    rescue
      return false
    end

    def update(keyword, status)
      return unless track = @tracks[keyword]
      status.push(track.name)
      artists = []
      track.artists.each do |artist|
        if @config['local']['nowplaying']['hashtag']
          artists.push(Mastodon.create_tag(artist.name))
        else
          artists.push(artist.name)
        end
      end
      status.push(artists.join(' '))
    end
  end
end
