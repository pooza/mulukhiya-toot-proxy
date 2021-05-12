module Mulukhiya
  class AmazonItemStorage < Redis
    def get(key)
      return nil unless entry = super
      return JSON.parse(entry)
    rescue => e
      logger.error(error: e, key: key)
      return nil
    end

    def set(key, values)
      setex(key, ttl, values.to_json)
    end

    def ttl
      return [config['/amazon/cache/ttl'], 86_400].min
    end

    def prefix
      return 'amazon_item'
    end
  end
end
