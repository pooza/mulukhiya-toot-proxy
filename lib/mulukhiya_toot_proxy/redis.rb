require 'redis'

module MulukhiyaTootProxy
  class Redis < ::Redis
    def initialize
      @config = Config.instance
      Config.validate('/local/redis/url')
      @url = Addressable::URI.parse(@config['local']['redis']['url'])
      raise RedisError, '正しいURLではありません。' unless @url.absolute?
      raise RedisError, '正しいスキームではありません。' unless @url.scheme == 'redis'
      super({url: @url.to_s})
    rescue => e
      raise RedisError, e.message
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

    def url
      return Addressable::URI.parse(@url)
    end
  end
end
