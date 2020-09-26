module Mulukhiya
  class AnnictPollingWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform
      AnnictStorage.accounts(&:crawl_annict)
    end
  end
end
