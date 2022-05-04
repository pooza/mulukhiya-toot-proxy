module Mulukhiya
  class AnnouncementWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless account_class.info_token
      return super
    end

    def perform(params = {})
      Announcement.new.announce
    end
  end
end
