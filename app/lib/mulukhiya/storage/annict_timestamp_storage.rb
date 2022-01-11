module Mulukhiya
  class AnnictTimestampStorage < Redis
    def get(key)
      return {} unless entry = super
      return JSON.parse(entry)
    rescue => e
      e.log(key:)
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
