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

    # 取れなかった acct (#4677)。`is_cat` は nil で、寿命は成功より短い。
    def remember_failure(acct)
      setex(acct, failure_ttl, {is_cat: nil, failed: true}.to_json)
    end

    def ttl
      return config['/account/is_cat/cache/ttl']
    end

    def failure_ttl
      return config['/account/is_cat/cache/failure_ttl']
    end

    def prefix
      return 'is_cat'
    end
  end
end
