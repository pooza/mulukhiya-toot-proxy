module Mulukhiya
  class UserConfigStorage < Redis
    def [](key)
      return JSON.parse(get(key)).key_flatten
    end

    def get(key)
      return super(create_key(key)) || '{}'
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
      set(key, JSON.parse(get(key)).deep_merge(values))
    end

    def create_key(key)
      return "user:#{key}"
    end
  end
end
