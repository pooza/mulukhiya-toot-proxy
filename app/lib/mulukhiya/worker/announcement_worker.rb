module Mulukhiya
  class AnnouncementWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless info_agent_service
      return super
    end

    def perform(params = {})
      # every 10m。info agent が無いサーバーでも Announcement#announce が走り、
      # 通知先の無いまま告知処理を回してしまう (#4506)。
      return if disable?
      announcement = Announcement.new
      announcement.announce
      log(cached: announcement.count)
    end
  end
end
