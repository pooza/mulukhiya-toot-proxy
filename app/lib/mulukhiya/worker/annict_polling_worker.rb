module Mulukhiya
  class AnnictPollingWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform
      AnnictService.crawl_all
    end
  end
end
