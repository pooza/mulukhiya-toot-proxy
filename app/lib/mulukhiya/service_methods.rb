module Mulukhiya
  module ServiceMethods
    def nodeinfo
      ttl = [config['/nodeinfo/cache/ttl'], 86_400].min
      redis.setex('nodeinfo', ttl, super.to_json)
      return JSON.parse(redis.get('nodeinfo'))
    end

    def account
      @account ||= Environment.account_class.get(token: token)
      return @account
    rescue
      return nil
    end

    def access_token
      return Environment.access_token_class.get(token: token)
      return nil
    rescue
      return nil
    end

    def clear_oauth_client
      redis.unlink('oauth_client')
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end

    def self.included(base)
      base.extend(Methods)
    end

    module Methods
    end
  end
end
