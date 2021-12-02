module Mulukhiya
  class AnnictAccountStorage < Redis
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
      return config['/annict/api/me/cache/ttl']
    end

    def prefix
      return 'annict_account'
    end

    def self.accounts(&block)
      return enum_for(__method__) unless block
      storage = UserConfigStorage.new
      storage.all_keys
        .map {|v| v.split(':').last}
        .select {|id| storage[id]['/annict/token']}
        .map {|id| Environment.account_class[id]}
        .select(&:webhook)
        .select(&:annict)
        .each(&block)
    end
  end
end
