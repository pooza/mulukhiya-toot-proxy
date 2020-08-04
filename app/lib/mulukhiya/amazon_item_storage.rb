module Mulukhiya
  class AmazonItemStorage < Redis
    def [](key)
      return get(key)
    end

    def []=(key, value)
      return set(key, value)
    end

    def get(key)
      return nil unless entry = super(create_key(key))
      return JSON.parse(entry)
    rescue => e
      @logger.error(Ginseng::RedisError, e.message)
      return nil
    end

    def set(key, values)
      setex(create_key(key), ttl, values.to_json)
    end

    def ttl
      return min(@config['/amazon/cache/ttl'], 86400)
    end

    def create_key(key)
      return "amazon:#{key}"
    end
  end
end
