module Mulukhiya
  class AnnictStorage < Redis
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
      @logger.error(Ginseng::RedisError, e.message)
      return nil
    end

    def set(key, values)
      super(create_key(key), values.to_json)
    end

    def account_ids
      return enum_for(__method__) unless block_given?
      userconfig_storage = UserConfigStorage.new
      keys('*').each do |key|
        type, id = key.split(':')
        next unless type == 'user'
        next unless userconfig_storage[id]['/annict/token']
        id = id.to_i if id.match?(/^[[:digit:]]+$/)
        yield id
      end
    end

    def create_key(key)
      return "annict:#{key}"
    end
  end
end
