module MulukhiyaTootProxy
  class ItunesNowplayingHandler < NowplayingHandler
    def initialize
      super
      @tracks = {}
      @service = ItunesService.new
    end

    def updatable?(keyword)
      return true if @tracks[keyword] = @service.search(keyword, 'music')
      return false
    rescue => e
      @logger.error(e)
      return false
    end

    def update(keyword)
      return unless track = @tracks[keyword]
      push(track['trackViewUrl'])
    end
  end
end
