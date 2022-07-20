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

    def self.accounts(&block)
      return enum_for(__method__) unless block
      storage = UserConfigStorage.new
      storage.all_keys
        .map {|key| key.split(':').last}
        .select {|id| storage[id]['/annict/token']}
        .filter_map {|id| Environment.account_class[id] rescue nil}
        .select(&:webhook)
        .select(&:annict)
        .each(&block)
    end
  end
end
