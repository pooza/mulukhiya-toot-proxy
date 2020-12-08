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
      if values['tags']
        values['tagging'] ||= {}
        values['tagging']['user_tags'] ||= values['tags']
        values.delete('tags')
      end
      if values['tagging']
        values['tagging']['user_tags'] = nil unless values['tagging']['user_tags'].present?
        values['tagging']['disabled_tags'] = nil unless values['tagging']['disabled_tags'].present?
      end
      set(key, JSON.parse(get(key)).deep_merge(values).select {|k, v| v.present?})
    end

    def prefix
      return 'user'
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
