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
      [:amazon_uri, :itunes_uri].each do |method|
        next unless uri = @service.send(method, track)
        status.push(uri.to_s)
      end
    end
  end
end
