module Mulukhiya
  class Announcement
    include Singleton
    include Package
    include SNSMethods
    attr_reader :storage

    def announce
      return unless controller_class.announcement?
      bar = ProgressBar.create(total: fetch.count) if Environment.rake?
      fetch.each do |announcement|
        next if cache.member?(announcement[:id])
        Event.new(:announce, {sns: info_agent_service}).dispatch(announcement)
      rescue => e
        logger.error(error: e, announcement: announcement)
      ensure
        bar&.increment
        sleep(1)
      end
      bar&.finish
      save
    end

    def fetch
      @announcements ||= info_agent_service.announcements
      return @announcements
    end

    def load
      return JSON.parse(storage['announcements'] || '{}')
    end

    alias cache load

    def save
      storage['announcements'] = fetch.to_h {|v| [v[:id], v]}.to_json
    rescue => e
      logger.error(error: e)
    end

    private

    def initialize
      @storage = Redis.new
    end
  end
end
