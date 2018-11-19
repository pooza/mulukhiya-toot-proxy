require 'json'

module MulukhiyaTootProxy
  class UserConfigStorage < Redis
    def [](key)
      return get(key)
    end

    def []=(key, value)
      set(key, value)
    end

    def get(key)
      v = super(create_key(key))
      v = JSON.parse(v) if v.present?
      return v || {}
    end

    def set(key, values)
      super(create_key(key), values.to_json)
      save
    end

    def del(key)
      super(create_key(key))
    end

    def update(key, values)
      set(key, get(key).update(values).compact)
    end

    def create_key(key)
      return "user:#{key}"
    end
  end
end
