module Mulukhiya
  class IsCatStorage < Redis
    def get(acct)
      return nil unless entry = super
      return JSON.parse(entry)
    rescue => e
      e.log(acct:)
      return nil
    end

    def set(acct, value)
      setex(acct, ttl, value.to_json)
    end

    def ttl
      return config['/account/is_cat/cache/ttl']
    end

    def prefix
      return 'is_cat'
    end
  end
end
