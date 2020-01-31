module Mulukhiya
  class SpotifyURLNowplayingHandler < NowplayingHandler
    def initialize(params = {})
      super(params)
      @tracks = {}
      @service = SpotifyService.new
    end

    def disable?
      return super || !SpotifyService.config?
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
      @tags = ArtistParser.new(track.artists.map(&:name).join('、')).parse
    end
  end
end
