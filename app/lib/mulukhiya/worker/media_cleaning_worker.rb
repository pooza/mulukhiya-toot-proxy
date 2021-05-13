module Mulukhiya
  class MediaCleaningWorker
    include Sidekiq::Worker
    sidekiq_options retry: false, unique: :until_executed

    def perform
      MediaFile.purge
    end
  end
end
