module Mulukhiya
  class AnnouncementWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless info_agent_service
      return super
    end

    def perform(params = {})
      Announcement.new.announce
    end
  end
end
