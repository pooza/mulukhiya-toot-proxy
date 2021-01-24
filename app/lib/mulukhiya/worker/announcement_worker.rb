module Mulukhiya
  class AnnouncementWorker
    include Package
    include SNSMethods
    include Sidekiq::Worker

    def perform
      return unless executable?
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

    private

    def cache
      return {} unless File.exist?(path)
      return JSON.parse(File.read(path))
    end

    def announcements
      @announcements ||= info_agent_service.announcements
      return @announcements
    end

    def save
      File.write(path, announcements.to_h {|v| [v[:id], v]}.to_json)
    rescue => e
      logger.error(error: e)
    end

    def path
      return File.join(Environment.dir, 'tmp/cache/announcements.json')
    end

    def executable?
      return controller_class.announcement?
    end
  end
end
