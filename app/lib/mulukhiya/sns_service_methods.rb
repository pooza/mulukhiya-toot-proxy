module Mulukhiya
  module SNSServiceMethods
    include SNSMethods

    def nodeinfo
      unless info = redis['nodeinfo']
        ttl = [config['/nodeinfo/cache/ttl'], 86_400].min
        info = super.to_json
        redis.setex('nodeinfo', ttl, info)
      end
      return JSON.parse(info)
    end

    def account
      @account ||= account_class.get(token: token) rescue nil
      return @account
    end

    def access_token
      @access_token ||= access_token_class.get(token: token) rescue nil
      return @access_token
    end

    def clear_oauth_client(type = :default)
      type ||= :default
      oauth_client_storage.unlink(type)
      redis.unlink('oauth_client') if type == :default
    end

    def oauth_client_storage
      @oauth_client_storage ||= OAuthClientStorage.new
      return @oauth_client_storage
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end
  end
end
