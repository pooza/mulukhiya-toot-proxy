require 'digest'

module Mulukhiya
  class RateLimitStorage < Redis
    INCREMENT_SCRIPT = <<~LUA.freeze
      local current = redis.call('INCR', KEYS[1])
      if current == 1 then
        redis.call('EXPIRE', KEYS[1], ARGV[1])
      end
      return current
    LUA
    INCREMENT_SCRIPT_SHA = Digest::SHA1.hexdigest(INCREMENT_SCRIPT).freeze

    def increment(key, window:)
      created = create_key(key)
      return redis.call('EVALSHA', INCREMENT_SCRIPT_SHA, 1, created, window).to_i
    rescue RedisClient::NoScriptError
      # Redis 再起動 / failover でスクリプトキャッシュが揮発したケース。
      # EVAL は実行と同時に SHA を再登録するため、以降は EVALSHA に戻る。
      return redis.call('EVAL', INCREMENT_SCRIPT, 1, created, window).to_i
    end

    def prefix
      return 'rate_limit'
    end
  end
end
