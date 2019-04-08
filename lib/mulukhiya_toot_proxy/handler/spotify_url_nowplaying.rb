module MulukhiyaTootProxy
  class SpotifyURLNowplayingHandler < NowplayingHandler
    def initialize
      super
      @tracks = {}
      @service = SpotifyService.new
    end

    def updatable?(keyword)
      return false unless uri = SpotifyURI.parse(keyword)
      return false unless uri.track.present?
      @tracks[keyword] = uri.track
      return true
    rescue => e
      @logger.error(e)
      return false
    end

    def update(keyword)
      return unless track = @tracks[keyword]
      push(track.name)
      push(track.artists.map(&:name).join(', '))
      ArtistParser.new(track.artists.map(&:name).join('、'), @tags).parse
      [:itunes_uri].each do |method|
        next unless uri = @service.send(method, track)
        push(uri.to_s)
      end
    end
  end
end
