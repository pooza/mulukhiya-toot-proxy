require 'redis'

module Mulukhiya
  class Redis < ::Redis
    include Package

    def initialize
      dsn = Redis.dsn
      dsn.db ||= 1
      raise Ginseng::RedisError, "Invalid DSN '#{dsn}'" unless dsn.absolute?
      raise Ginseng::RedisError, "Invalid scheme '#{dsn.scheme}'" unless dsn.scheme == 'redis'
      super(url: dsn.to_s)
    end

    def get(key)
      return super
    rescue => e
      raise Ginseng::RedisError, e.message, e.backtrace
    end

    def set(key, value)
      return super
    rescue => e
      raise Ginseng::RedisError, e.message, e.backtrace
    end

    def unlink(key)
      return super
    rescue => e
      raise Ginseng::RedisError, e.message, e.backtrace
    end

    alias del unlink

    def self.dsn
      return Ginseng::RedisDSN.parse(config['/user_config/redis/dsn'])
    end

    def self.health
      redis = Redis.new
      redis.get('1')
      return {status: 'OK'}
    rescue => e
      return {error: e.message, status: 'NG'}
    end
  end
end
