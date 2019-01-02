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

    def update(keyword, status)
      return unless track = @tracks[keyword]
      status.push(track['trackName'])
      status.push(ArtistParser.new(track['artistName']).parse.join(' '))
      [:amazon_uri, :spotify_uri].each do |method|
        next unless uri = @service.send(method, track)
        status.push(uri.to_s)
      end
    end
  end
end
