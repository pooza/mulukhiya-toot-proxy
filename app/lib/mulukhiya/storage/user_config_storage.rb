module Mulukhiya
  class UserConfigStorage < Redis
    def [](key)
      return JSON.parse(get(key)).key_flatten
    end

    def get(key)
      return super || '{}'
    end

    def set(key, values)
      super(key, values.except('c', 'command').to_json)
      save
      log(key:)
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
      bar = ProgressBar.create(total: accounts.count)
      tag_owners do |account|
        account.user_config.clear_tags
      ensure
        bar&.increment
      end
      bar&.finish
    end

    def self.tag_owners(&block)
      return enum_for(__method__) unless block
      accounts.select {|v| v.user_config['/tagging/user_tags'].present?}.each(&block)
    end

    def self.accounts(&block)
      return enum_for(__method__) unless block
      new.all_keys
        .map {|key| key.split(':').last}
        .filter_map {|id| Environment.account_class[id] rescue nil}
        .each(&block)
    end
  end
end
