module Mulukhiya
  class MediaCleaningWorker < Worker
    sidekiq_options retry: false

    def perform(params = {})
      MediaFile.purge
    end
  end
end
