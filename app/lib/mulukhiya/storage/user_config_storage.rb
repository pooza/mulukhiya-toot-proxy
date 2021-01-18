module Mulukhiya
  class UserConfigStorage < Redis
    def [](key)
      return JSON.parse(get(key)).key_flatten
    end

    def get(key)
      return super(create_key(key)) || '{}'
    end

    def set(key, values)
      ['c', 'command'].each {|k| values.delete(k) if values.member?(k)}
      super(create_key(key), values.to_json)
      save
    end

    def del(key)
      super(create_key(key))
    end

    def update(key, values)
      values.deep_stringify_keys!
      if values.key?('tags')
        values['tagging'] ||= {}
        values['tagging']['user_tags'] ||= values['tags']
        values.delete('tags')
      end
      set(key, JSON.parse(get(key)).deep_merge(values).deep_compact)
    end

    def prefix
      return 'user'
    end

    def self.clear_tags
      bar = ProgressBar.create(total: accounts.count) if Environment.rake?
      accounts do |account|
        next unless account.user_config['/tagging/user_tags'].present?
        account.user_config.clear_tags
      ensure
        bar&.increment
      end
      bar&.finish
    end

    def self.accounts
      return enum_for(__method__) unless block_given?
      storage = UserConfigStorage.new
      storage.all_keys.each do |key|
        id = key.split(':').last
        next unless storage[id]['/tagging/user_tags']
        id = id.to_i if id.match?(/^[[:digit:]]+$/)
        next unless account = Environment.account_class[id]
        yield account
      end
    end
  end
end
