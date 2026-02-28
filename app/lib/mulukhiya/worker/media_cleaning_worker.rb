module Mulukhiya
  class MediaCleaningWorker < Worker
    sidekiq_options retry: false

    def perform(params = {})
      before = MediaFile.all.count
      MediaFile.purge
      log(before:, after: MediaFile.all.count)
    end
  end
end
