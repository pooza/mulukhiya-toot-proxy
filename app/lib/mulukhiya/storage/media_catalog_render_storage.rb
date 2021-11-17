module Mulukhiya
  class MediaCatalogRenderStorage < RenderStorage
    def get(key)
      return super&.map(&:deep_symbolize_keys)
    end

    def setex(key, ttl, value)
      super
      logger.info(class: self.class.to_s, message: 'update', page: key[:page])
    end

    def ttl
      return config['/webui/media/cache/ttl']
    end

    def create_key(key)
      return "#{prefix}:#{key[:page].to_i}" if key.is_a?(Hash)
      return key
    end

    def prefix
      return 'media_catalog'
    end
  end
end
