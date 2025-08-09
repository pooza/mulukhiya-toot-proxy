module Mulukhiya
  class Announcement
    include Package
    include SNSMethods

    attr_reader :storage, :sns

    def initialize
      @storage = Redis.new
      @sns = info_agent_service
    end

    def announce
      return unless controller_class.announcement?
      response = fetch
      response.reject {|v| cache.member?(v[:id])}.each do |announcement|
        Event.new(:announce, {sns:}).dispatch(announcement)
      rescue => e
        e.log(announcement:)
      ensure
        sleep(Worker.create(:announcement).worker_config('interval/seconds'))
      end
      save(response)
    end

    def fetch
      return sns&.announcements || []
    end

    def load
      return JSON.parse(storage['announcements'] || '{}')
    end

    def count
      return load.count
    end

    alias cache load

    def save(response)
      storage['announcements'] = response.to_h {|v| [v[:id], v]}.to_json
    rescue => e
      e.alert
    end
  end
end
