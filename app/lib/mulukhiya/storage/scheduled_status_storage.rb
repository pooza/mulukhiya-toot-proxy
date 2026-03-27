module Mulukhiya
  class ScheduledStatusStorage < Redis
    def get(key)
      return nil unless entry = super
      return JSON.parse(entry, symbolize_names: true)
    rescue => e
      e.log(key:)
      return nil
    end

    def set(key, values, ttl: nil)
      if ttl
        setex(key, ttl, values.to_json)
      else
        super(key, values.to_json)
      end
    end

    def prefix
      return 'scheduled_status'
    end
  end
end
