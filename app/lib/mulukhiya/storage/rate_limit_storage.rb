module Mulukhiya
  class RateLimitStorage < Redis
    INCREMENT_SCRIPT = <<~LUA.freeze
      local current = redis.call('INCR', KEYS[1])
      if current == 1 then
        redis.call('EXPIRE', KEYS[1], ARGV[1])
      end
      return current
    LUA

    def increment(key, window:)
      created = create_key(key)
      return redis.call('EVAL', INCREMENT_SCRIPT, 1, created, window).to_i
    end

    def prefix
      return 'rate_limit'
    end
  end
end
