module Mulukhiya
  class SpotifyURLNowplayingHandler < NowplayingHandler
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
      push(uri.title.escape_toot)
      push(uri.artists.map(&:escape_toot).join(','))
      tags.concat(uri.artists)
      result.push(url: uri.to_s, artists: uri.artists)
    end
  end
end
