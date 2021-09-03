module Mulukhiya
  class MediaCleaningWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform
      MediaFile.purge
    end
  end
end
