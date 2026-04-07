module Mulukhiya
  class MediaCatalogStorage < Redis
    PAGE1_TTL = 180
    DEFAULT_TTL = 86_400

    def get(key)
      return nil unless entry = super
      return JSON.parse(entry, symbolize_names: true)
    rescue => e
      e.log(key:)
      return nil
    end

    def set(key, value, ttl: nil)
      ttl ||= key.to_s.match?(/\bpage:1\b/) ? PAGE1_TTL : DEFAULT_TTL
      setex(key, ttl, value.to_json)
    end

    def prefix
      return 'media_catalog'
    end
  end
end
