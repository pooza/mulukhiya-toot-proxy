module Mulukhiya
  class AnnictPollingWorker < Worker
    sidekiq_options retry: false

    def perform(params = {})
      return unless controller_class.annict?
      AnnictService.crawl_all
    end
  end
end
