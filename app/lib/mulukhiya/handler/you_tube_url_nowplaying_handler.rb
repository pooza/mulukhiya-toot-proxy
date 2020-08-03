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
      if uri.music?
        push(uri.artist)
        tags.push(uri.artist)
        result.push(url: uri.to_s, artist: uri.artist)
      else
        push(uri.channel)
        tags.push(uri.channel)
        result.push(url: uri.to_s, channel: uri.channel)
      end
    end
  end
end
