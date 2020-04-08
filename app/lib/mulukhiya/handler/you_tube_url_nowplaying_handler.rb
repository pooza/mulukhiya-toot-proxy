module Mulukhiya
  class YouTubeURLNowplayingHandler < NowplayingHandler
    def initialize(params = {})
      super(params)
      @videos = {}
    end

    def disable?
      return super || !YouTubeService.config?
    end

    def updatable?(keyword)
      return false unless uri = VideoURI.parse(keyword)
      return false unless @videos[keyword] = uri.data&.merge('url' => uri.to_s)
      return true
    rescue => e
      errors.push(class: e.class.to_s, message: e.message)
      return false
    end

    def update(keyword)
      return unless video = @videos[keyword]
      push(video['snippet']['title'])
      push(video['snippet']['channelTitle'])
      tags.push(video['snippet']['channelTitle'])
      result.push(url: video['url'])
    end
  end
end
