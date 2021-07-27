module Mulukhiya
  class Announce
    include Package
    include SNSMethods
    attr_reader :storage, :sns

    def initialize
      @storage = Redis.new
      @sns = info_agent_service
    end

    def announce
      return unless controller_class.announcement?
      bar = ProgressBar.create(total: fetch.count)
      fetch.each do |announcement|
        next if cache.member?(announcement[:id])
        Event.new(:announce, {sns: sns}).dispatch(announcement)
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
      @announcements ||= sns.announcements
      return @announcements
    end

    def load
      return JSON.parse(storage['announcements'] || '{}')
    end

    def count
      return load.count
    end

    alias cache load

    def save
      storage['announcements'] = fetch.to_h {|v| [v[:id], v]}.to_json
    rescue => e
      logger.error(error: e)
    end
  end
end
