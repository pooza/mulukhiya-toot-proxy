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
      return false unless @videos[keyword] = uri.data
      return true
    rescue => e
      @logger.error(e)
      return false
    end

    def update(keyword)
      return unless video = @videos[keyword]
      push(video['snippet']['title'])
      push(video['snippet']['channelTitle'])
      tags.push(video['snippet']['channelTitle'])
    end
  end
end
