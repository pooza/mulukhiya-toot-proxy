module Mulukhiya
  class SpotifyURLNowplayingHandler < NowplayingHandler
    def initialize(params = {})
      super
      @uris = {}
    end

    def disable?
      return super || !SpotifyService.config?
    end

    def updatable?(keyword)
      return false unless uri = SpotifyURI.parse(keyword)
      return false if uri.track.nil? && uri.album.nil?
      @uris[keyword] = uri
      return true
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword: keyword)
      return false
    end

    def update(keyword)
      return unless uri = @uris[keyword]
      if uri.album
        push(uri.album.name)
        push(uri.album.artists.map(&:name).join(', '))
        tags.concat(ArtistParser.new(uri.album.artists.map(&:name).join('、')).parse)
      elsif uri.track
        push(uri.track.name)
        push(uri.track.artists.map(&:name).join(', '))
        tags.concat(ArtistParser.new(uri.track.artists.map(&:name).join('、')).parse)
      end
      result.push(url: uri.to_s)
    end
  end
end
