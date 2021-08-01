module Mulukhiya
  class AnnouncementWorker
    include Sidekiq::Worker
    sidekiq_options retry: false, unique: :until_executed

    def perform
      sleep(config['/worker/announcement/prior/seconds'])
      Announcement.new.announce
    end
  end
end
