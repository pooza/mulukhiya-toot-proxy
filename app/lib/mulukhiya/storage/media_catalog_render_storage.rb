module Mulukhiya
  class MediaCatalogRenderStorage < RenderStorage
    def get(key)
      return super&.map(&:deep_symbolize_keys)
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
