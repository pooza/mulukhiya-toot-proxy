module Mulukhiya
  class AnnouncementWorker < Worker
    sidekiq_options retry: false

    def perform(params = {})
      Announcement.new.announce
    end

    def interval_seconds
      return worker_config('interval/seconds')
    end
  end
end
