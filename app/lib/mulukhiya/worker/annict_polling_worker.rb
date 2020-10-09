module Mulukhiya
  class AnnictPollingWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform
      AnnictAccountStorage.accounts(&:crawl_annict)
    end
  end
end
