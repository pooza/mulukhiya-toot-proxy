module Mulukhiya
  class CustomAPIRenderStorage < RenderStorage
    def get(key)
      return super&.map(&:deep_symbolize_keys)
    end

    def setex(key, ttl, value)
      super
      logger.info(class: self.class.to_s, method: __method__, page: key[:page])
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
