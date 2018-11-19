require 'json'

module MulukhiyaTootProxy
  class UserConfigStorage < Redis
    def [](key)
      return get("user:#{key}")
    end

    def update(key, values)
      v = get("user:#{key}")
      v = JSON.parse(v) if v.present?
      v ||= {}
      v.update(values)
      v.compact!
      set("user:#{key}", v.to_json)
      save
    end
  end
end
