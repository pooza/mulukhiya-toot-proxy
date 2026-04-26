module Mulukhiya
  class RateLimitStorage < Redis
    def increment(key, window:)
      created = create_key(key)
      count = redis.call('INCR', created)
      redis.call('EXPIRE', created, window) if count == 1
      return count
    end

    def prefix
      return 'rate_limit'
    end
  end
end
