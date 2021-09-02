module Mulukhiya
  class AnnouncementWorker
    include Sidekiq::Worker
    sidekiq_options retry: false, lock: :until_executed, on_conflict: :log

    def perform
      Announcement.new.announce
    end
  end
end
