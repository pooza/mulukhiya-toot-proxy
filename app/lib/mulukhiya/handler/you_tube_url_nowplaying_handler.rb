module Mulukhiya
  class YouTubeURLNowplayingHandler < NowplayingHandler
    def disable?
      return super || !YouTubeService.config?
    end

    def updatable?(keyword)
      return false unless uri = VideoURI.parse(keyword)
      return false unless uri.id
      @uris[keyword] = uri
      return true
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, keyword: keyword)
      return false
    end

    def update(keyword)
      return unless uri = @uris[keyword]
      push(uri.title)
      push(uri.artist)
      tags.concat(ArtistParser.new(uri.artist).parse)
      result.push(url: uri.to_s, artist: uri.artist)
    end
  end
end
