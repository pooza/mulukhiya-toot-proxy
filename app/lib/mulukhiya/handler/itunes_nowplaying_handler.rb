module Mulukhiya
  class ItunesNowplayingHandler < NowplayingHandler
    def initialize(params = {})
      super(params)
      @tracks = {}
      @service = ItunesService.new
    end

    def updatable?(keyword)
      return true if @tracks[keyword] = @service.search(keyword, 'music')
      return false
    rescue => e
      errors.push(class: e.class.to_s, message: e.message)
      return false
    end

    def update(keyword)
      return unless track = @tracks[keyword]
      push(track['trackViewUrl'])
      result.push(keyword: keyword)
    end
  end
end
