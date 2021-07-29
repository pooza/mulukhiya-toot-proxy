module Mulukhiya
  class AnnouncementWorker
    include Sidekiq::Worker
    sidekiq_options retry: false, unique: :until_executed

    def perform
      Announcement.new.announce
    end
  end
end
