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
        if @config['/nowplaying/hashtag']
          artists.concat(ArtistParser.new(artist.name).parse)
        else
          artists.push(artist.name)
        end
      end
      status.push(artists.uniq.compact.join(' '))
      return unless uri = @service.amazon_uri(track)
      status.push(uri.to_s)
      return unless uri = @service.itunes_uri(track)
      status.push(uri.to_s)
    end
  end
end
