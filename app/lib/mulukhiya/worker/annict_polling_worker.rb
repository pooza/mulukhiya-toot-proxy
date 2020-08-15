module Mulukhiya
  class AnnictPollingWorker
    include Sidekiq::Worker

    def perform
      AnnictStorage.accounts(&:crawl_annict)
    end
  end
end
