module Mulukhiya
  class AnnouncementWorker
    include Package
    include Sidekiq::Worker

    def initialize
      @sns = Environment.info_agent_service
    end

    def perform
      return unless executable?
      @sns.announcements.each do |announcement|
        next if cache.member?(announcement[:id])
        Event.new(:announce, {sns: @sns}).dispatch(announcement)
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

    def save
      File.write(path, @sns.announcements.to_h {|v| [v[:id], v]}.to_json)
    rescue => e
      logger.error(error: e)
    end

    def path
      return File.join(Environment.dir, 'tmp/cache/announcements.json')
    end

    def executable?
      return Environment.controller_class.announcement?
    end
  end
end
