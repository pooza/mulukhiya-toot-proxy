module MulukhiyaTootProxy
  class YouTubeURLNowplayingHandler < NowplayingHandler
    def initialize
      super
      @videos = {}
      @service = YouTubeService.new
    end

    def updatable?(keyword)
      return false unless uri = VideoURI.parse(keyword)
      return false unless @videos[keyword] = uri.data
      return true
    rescue
      return false
    end

    def update(keyword)
      return unless video = @videos[keyword]
      push(video['snippet']['title'])
      push(video['snippet']['channelTitle'])
    end
  end
end
