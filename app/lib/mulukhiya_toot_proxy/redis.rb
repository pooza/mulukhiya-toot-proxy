require 'redis'

module MulukhiyaTootProxy
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

    def del(key)
      return super(key)
    rescue => e
      raise Ginseng::RedisError, e.message, e.backtrace
    end

    def self.dsn
      return RedisDSN.parse(Config.instance['/user_config/redis/dsn'])
    end

    def self.health
      Redis.new.get('1')
      return {status: 'OK'}
    rescue
      return {status: 'NG'}
    end
  end
end
