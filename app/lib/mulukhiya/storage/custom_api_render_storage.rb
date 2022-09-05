module Mulukhiya
  class CustomAPIRenderStorage < RenderStorage
    def get(key)
      return super&.deep_symbolize_keys
    end

    def ttl
      return config['/api/cache/ttl']
    end

    def create_key(key)
      return "#{prefix}:#{key.to_json.sha256}" if key.is_a?(Hash)
    end

    def prefix
      return 'custom_api'
    end
  end
end
