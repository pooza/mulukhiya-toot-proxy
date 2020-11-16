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
      push(uri.titie.escape_toot)
      push(uri.artists.map(:escape_root).join(','))
      tags.concat(ArtistParser.new(uri.artists.join(',')).parse)
      result.push(url: uri.to_s, artist: uri.artists)
    end
  end
end
