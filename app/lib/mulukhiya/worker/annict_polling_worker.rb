module Mulukhiya
  class AnnictPollingWorker
    include Sidekiq::Worker
    include Package
    include SNSMethods
    sidekiq_options retry: false

    def perform
      return unless controller_class.annict?
      AnnictService.crawl_all
    end
  end
end
