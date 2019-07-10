module MulukhiyaTootProxy
  class Toot
    attr_reader :params

    def initialize(key)
      @logger = Logger.new
      @params = Mastodon.lookup_toot(key[:id])
    end

    def id
      return self[:id]&.to_i
    end

    def account
      @account ||= Account.new(id: self[:account_id])
      return @account
    end

    alias to_h params

    def [](key)
      return @params[key]
    end
  end
end
