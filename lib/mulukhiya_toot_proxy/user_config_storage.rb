module MulukhiyaTootProxy
  class UserConfigStorage < Redis
    def [](key)
      value = get(key)
      return {} if value.nil?
      return Config.flatten('', JSON.parse(value))
    end

    def get(key)
      return super(create_key(key))
    end

    def set(key, values)
      values.delete('command') if values.member?('command')
      super(create_key(key), values.to_json)
      save
    end

    def del(key)
      super(create_key(key))
    end

    def update(key, values)
      set(key, Config.deep_merge(JSON.parse(get(key) || '{}'), values))
    end

    def create_key(key)
      return "user:#{key}"
    end
  end
end
