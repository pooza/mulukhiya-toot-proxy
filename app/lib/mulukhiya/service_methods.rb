module Mulukhiya
  module ServiceMethods
    def nodeinfo
      unless info = redis.get('nodeinfo')
        ttl = [config['/nodeinfo/cache/ttl'], 86_400].min
        info = super.to_json
        redis.setex('nodeinfo', ttl, info)
      end
      return JSON.parse(info)
    end

    def account
      @account ||= Environment.account_class.get(token: token)
      return @account
    rescue
      return nil
    end

    def access_token
      @access_token ||= Environment.access_token_class.get(token: token)
      return @access_token
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
