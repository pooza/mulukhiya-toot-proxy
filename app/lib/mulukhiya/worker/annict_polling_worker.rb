module Mulukhiya
  class AnnictPollingWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform
      AnnictAccountStorage.accounts do |account|
        account.annict.crawl(webhook: account.webhook)
      end
    end
  end
end
