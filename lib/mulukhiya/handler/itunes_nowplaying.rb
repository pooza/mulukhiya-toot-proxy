require 'mulukhiya/itunes_service'
require 'mulukhiya/handler/nowplaying_handler'

module MulukhiyaTootProxy
  class ItunesNowplayingHandler < NowplayingHandler
    def initialize
      super
      @tracks = {}
      @service = ItunesService.new
    end

    def updatable?(keyword)
      return false unless track = @service.search(keyword, 'music')
      @tracks[keyword] = track
      return true
    end

    def update(keyword, status)
      return unless track = @tracks[keyword]
      status.push(track['trackViewUrl'])
    end
  end
end
