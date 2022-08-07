module Mulukhiya
  class OAuthClientStorage < Redis
    def get(key)
      return nil unless entry = super
      return JSON.parse(entry)
    rescue => e
      e.log(key:)
      return nil
    end

    def set(key, values)
      super(key, values.to_json)
    end

    def create_key(key)
      return super(key.to_json.sha256)
    end

    def prefix
      return 'oauth_client'
    end
  end
end
