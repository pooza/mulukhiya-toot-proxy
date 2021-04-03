module Mulukhiya
  class AnnouncementWorker
    include Package
    include SNSMethods
    include Sidekiq::Worker
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
      if File.exist?(path)
        redis.set('announcements', JSON.parse(File.read(path)))
        File.unlink(path)
      end
      return JSON.parse(redis.get('announcements') || '{}')
    end

    def announcements
      @announcements ||= info_agent_service.announcements
      return @announcements
    end

    private

    def save
      redis.set('announcements', announcements.to_h {|v| [v[:id], v]}.to_json)
    rescue => e
      logger.error(error: e)
    end

    def path
      return File.join(Environment.dir, 'tmp/cache/announcements.json')
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end
  end
end
