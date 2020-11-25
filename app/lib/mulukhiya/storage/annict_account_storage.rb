module Mulukhiya
  class AnnictAccountStorage < Redis
    def [](key)
      return get(key)
    end

    def []=(key, value)
      set(key, value)
    end

    def get(key)
      return nil unless entry = super(create_key(key))
      return JSON.parse(entry)
    rescue => e
      @logger.error(error: e, key: key)
      return nil
    end

    def set(key, values)
      setex(create_key(key), ttl, values.to_json)
    end

    def ttl
      return @config['/annict/api/me/cache/ttl']
    end

    def prefix
      return 'annict_account'
    end

    def self.accounts
      return enum_for(__method__) unless block_given?
      storage = UserConfigStorage.new
      storage.all_keys.each do |key|
        id = key.split(':').last
        next unless storage[id]['/annict/token']
        id = id.to_i if id.match?(/^[[:digit:]]+$/)
        next unless account = Environment.account_class[id]
        next unless account.webhook
        next unless account.annict
        yield account
      end
    end
  end
end
