module Mulukhiya
  class OAuthClientStorage < JSONStorage
    def create_key(key)
      return super(key.to_json.sha256)
    end

    def prefix
      return 'oauth_client'
    end
  end
end
