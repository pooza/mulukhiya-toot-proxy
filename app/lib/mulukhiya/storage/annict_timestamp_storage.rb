module Mulukhiya
  class AnnictTimestampStorage < Redis
    def [](key)
      return get(key) || {}
    end

    def []=(key, value)
      set(key, value)
    end

    def get(key)
      return nil unless entry = super(create_key(key))
      return JSON.parse(entry)
    rescue => e
      logger.error(error: e, key: key)
      return nil
    end

    def set(key, values)
      super(create_key(key), values.to_json)
    end

    def prefix
      return 'annict'
    end
  end
end
