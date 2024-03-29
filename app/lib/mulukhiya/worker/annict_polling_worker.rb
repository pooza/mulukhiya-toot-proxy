module Mulukhiya
  class AnnictPollingWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless controller_class.annict?
      return super
    end

    def perform(params = {})
      AnnictService.crawl_all
    end
  end
end
