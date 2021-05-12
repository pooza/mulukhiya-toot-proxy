module Mulukhiya
  class AnnictTimestampStorage < Redis
    def get(key)
      return {} unless entry = super
      return JSON.parse(entry)
    rescue => e
      logger.error(error: e, key: key)
      return {}
    end

    def set(key, values)
      super(key, values.to_json)
    end

    def prefix
      return 'annict'
    end
  end
end
