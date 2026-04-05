module Mulukhiya
  class IsCatStorage < Redis
    DEFAULT_TTL = 86_400

    def get(acct)
      return nil unless entry = super(acct)
      return JSON.parse(entry)
    rescue => e
      e.log(acct:)
      return nil
    end

    def set(acct, value)
      setex(acct, DEFAULT_TTL, value.to_json)
    end

    def prefix
      return 'is_cat'
    end
  end
end
