module Mulukhiya
  class SpotifyURLNowplayingHandler < NowplayingHandler
    def initialize(params = {})
      super(params)
      @uris = {}
      @service = SpotifyService.new
    end

    def disable?
      return super || !SpotifyService.config?
    end

    def updatable?(keyword)
      return false unless uri = SpotifyURI.parse(keyword)
      return false unless uri.track.present?
      @uris[keyword] = uri
      return true
    rescue => e
      errors.push(class: e.class.to_s, message: e.message)
      return false
    end

    def update(keyword)
      return unless uri = @uris[keyword]
      push(uri.track.name)
      push(uri.track.artists.map(&:name).join(', '))
      tags.concat(ArtistParser.new(uri.track.artists.map(&:name).join('、')).parse)
      result.push(url: uri.to_s)
    end
  end
end
