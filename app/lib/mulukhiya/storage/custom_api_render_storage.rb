module Mulukhiya
  class CustomAPIRenderStorage < RenderStorage
    def get(key)
      return super&.deep_symbolize_keys
    end

    def ttl
      return config['/api/cache/ttl']
    end

    def create_key(key)
      return "#{prefix}:#{key.to_json.adler32}" if key.is_a?(Hash)
      return key
    end

    def prefix
      return 'custom_api'
    end
  end
end
