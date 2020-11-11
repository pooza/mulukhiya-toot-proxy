module Mulukhiya
  class ItunesURLNowplayingHandler < NowplayingHandler
    def updatable?(keyword)
      return false unless uri = ItunesURI.parse(keyword)
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
        push(uri.track['trackName'].escape_toot)
        artist = uri.track['artistName']
      elsif uri.album
        push(uri.album['collectionName'].escape_toot)
        artist = uri.album['artistName']
      end
      push(artist.escape_toot)
      tags.concat(ArtistParser.new(artist).parse)
      result.push(url: uri.to_s, artist: artist)
    end
  end
end
