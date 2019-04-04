require 'redis'
require 'addressable/uri'

module MulukhiyaTootProxy
  class Redis < ::Redis
    def initialize
      dsn = Redis.dsn
      dsn.db ||= 1
      raise Ginseng::RedisError, "Invalid DSN '#{dsn}'" unless dsn.absolute?
      raise Ginseng::RedisError, "Invalid scheme '#{dsn.scheme}'" unless dsn.scheme == 'redis'
      super({url: dsn.to_s})
    end

    def get(key)
      return super(key)
    rescue => ex
      raise Ginseng::RedisError, ex.message
    end

    def set(key, value)
      return super(key, value)
    rescue => ex
      raise Ginseng::RedisError, ex.message
    end

    def del(key)
      return super(key)
    rescue => ex
      raise Ginseng::RedisError, ex.message
    end

    def self.dsn
      return RedisDSN.parse(Config.instance['/redis/dsn'])
    end
  end
end
