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
      value = super(create_key(key))
      value = JSON.parse(value) unless value.nil?
      return value || {}
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
      set(key, get(key).update(values).compact)
    end

    def create_key(key)
      return "user:#{key}"
    end
  end
end
