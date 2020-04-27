module Mulukhiya
  class SpotifyURLNowplayingHandler < NowplayingHandler
    def initialize(params = {})
      super
      @uris = {}
      @service = SpotifyService.new
    rescue => e
      errors.push(class: e.class.to_s, message: e.message)
    end

    def disable?
      return super || !SpotifyService.config? || !@service
    end

    def updatable?(keyword)
      return false unless uri = SpotifyURI.parse(keyword)
      return false unless uri.track.present?
      @uris[keyword] = uri
      return true
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword: keyword)
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
