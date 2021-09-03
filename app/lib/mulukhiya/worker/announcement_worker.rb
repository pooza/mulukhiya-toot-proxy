module Mulukhiya
  class AnnouncementWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform
      Announcement.new.announce
    end
  end
end
