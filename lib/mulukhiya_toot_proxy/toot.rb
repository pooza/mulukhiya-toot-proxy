module MulukhiyaTootProxy
  class Toot
    attr_reader :params

    def initialize(key)
      @params = Mastodon.lookup_toot(key[:id])
      @config = Config.instance
    end

    def id
      return self[:id]&.to_i
    end

    def account
      @account ||= Account.new(id: self[:account_id])
      return @account
    end

    def uri
      unless @uri
        @uri = MastodonURI.parse(@config['/mastodon/url'])
        @uri.path = "/@#{account.username}/#{id}"
      end
      return @uri
    end

    alias to_h params

    def [](key)
      return @params[key]
    end
  end
end
