require 'redis'

module Mulukhiya
  class Redis < ::Redis
    def initialize
      dsn = Redis.dsn
      dsn.db ||= 1
      raise Ginseng::RedisError, "Invalid DSN '#{dsn}'" unless dsn.absolute?
      raise Ginseng::RedisError, "Invalid scheme '#{dsn.scheme}'" unless dsn.scheme == 'redis'
      super(url: dsn.to_s)
    end

    def get(key)
      return super(key)
    rescue => e
      raise Ginseng::RedisError, e.message, e.backtrace
    end

    def set(key, value)
      return super(key, value)
    rescue => e
      raise Ginseng::RedisError, e.message, e.backtrace
    end

    def unlink(key)
      return super(key)
    rescue => e
      raise Ginseng::RedisError, e.message, e.backtrace
    end

    alias del unlink

    def self.dsn
      return Ginseng::RedisDSN.parse(Config.instance['/user_config/redis/dsn'])
    end

    def self.health
      redis = Redis.new
      redis.get('1')
      return {
        version: redis.info['redis_version'],
        status: 'OK',
      }
    rescue => e
      return {error: e.message, status: 'NG'}
    end
  end
end
