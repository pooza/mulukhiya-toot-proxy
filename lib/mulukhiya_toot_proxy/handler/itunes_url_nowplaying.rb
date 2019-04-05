module MulukhiyaTootProxy
  class ItunesURLNowplayingHandler < NowplayingHandler
    def initialize
      super
      @tracks = {}
      @service = ItunesService.new
    end

    def updatable?(keyword)
      return false unless uri = ItunesURI.parse(keyword)
      return false unless uri.track.present?
      @tracks[keyword] = uri.track
      return true
    rescue
      return false
    end

    def update(keyword)
      return unless track = @tracks[keyword]
      push(track['trackName'])
      push(track['artistName'])
      ArtistParser.new(track['artistName'], @tags).parse
      [:spotify_uri].each do |method|
        next unless uri = @service.send(method, track)
        push(uri.to_s)
      end
    end
  end
end
