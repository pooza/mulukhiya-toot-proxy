module Mulukhiya
  class MediaCleaningWorker
    include Sidekiq::Worker
    sidekiq_options retry: false, lock: :until_executed

    def perform
      MediaFile.purge
    end
  end
end
