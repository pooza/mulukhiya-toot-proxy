module Mulukhiya
  class OAuthStateStorage < Redis
    TTL = 600

    def get(key)
      return nil unless entry = super
      return JSON.parse(entry, symbolize_names: true)
    rescue => e
      e.log(key:)
      return nil
    end

    def set(key, values)
      setex(key, TTL, values.to_json)
    end

    def consume(key)
      return nil unless entry = get(key)
      unlink(key)
      return entry
    end

    def prefix
      return 'oauth_state'
    end
  end
end
