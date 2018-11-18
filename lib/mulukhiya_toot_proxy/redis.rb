require 'redis'
require 'addressable/uri'

module MulukhiyaTootProxy
  class Redis < ::Redis
    def initialize
      dsn = Redis.dsn
      dsn.db ||= 1
      raise RedisError, "Invalid DSN '#{dsn}'" unless dsn.absolute?
      raise RedisError, "Invalid scheme '#{dsn.scheme}'" unless dsn.scheme == 'redis'
      super({url: dsn.to_s})
    end

    def get(key)
      return super(key)
    rescue => e
      raise RedisError, e.message
    end

    def set(key, value)
      return super(key, value)
    rescue => e
      raise RedisError, e.message
    end

    def del(key)
      return super(key)
    rescue => e
      raise RedisError, e.message
    end

    def self.dsn
      return RedisDSN.parse(Config.instance['local']['redis']['dsn'])
    rescue
      return RedisDSN.parse('redis://localhost:6379/1')
    end
  end
end
