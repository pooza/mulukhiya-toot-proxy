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
      if uri.track
        push(uri.track.name.escape_toot)
        artists = uri.track.artists
      elsif uri.album
        push(uri.album.name.escape_toot)
        artists = uri.album.artists
      end
      push(artists.map(&:name).join(', '))
      tags.concat(ArtistParser.new(artists.map(&:name).map(&:escape_toot).join('、')).parse)
      result.push(url: uri.to_s, artists: artists.map(&:name))
    end
  end
end
