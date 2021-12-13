module Mulukhiya
  class MediaCleaningWorker < Worker
    sidekiq_options retry: false

    def perform(params = {})
      MediaFile.purge
    end

    def days
      return worker_config(:days)
    end
  end
end
