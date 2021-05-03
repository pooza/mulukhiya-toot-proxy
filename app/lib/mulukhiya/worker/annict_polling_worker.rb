module Mulukhiya
  class AnnictPollingWorker
    include Sidekiq::Worker
    include Package
    sidekiq_options retry: false, lock: :until_executed

    def perform
      return unless controller_class.annict?
      AnnictService.crawl_all
    end
  end
end
