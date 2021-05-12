module Mulukhiya
  class AnnouncementWorker
    include Sidekiq::Worker
    include Package
    include SNSMethods
    sidekiq_options retry: false, lock: :until_executed

    def perform
      return unless controller_class.announcement?
      announcements.each do |announcement|
        next if cache.member?(announcement[:id])
        Event.new(:announce, {sns: info_agent_service}).dispatch(announcement)
      rescue => e
        logger.error(error: e, announcement: announcement)
      ensure
        sleep(1)
      end
      save
    end

    def cache
      return JSON.parse(redis['announcements'] || '{}')
    end

    def announcements
      @announcements ||= info_agent_service.announcements
      return @announcements
    end

    private

    def save
      redis['announcements'] = announcements.to_h {|v| [v[:id], v]}.to_json
    rescue => e
      logger.error(error: e)
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end
  end
end
