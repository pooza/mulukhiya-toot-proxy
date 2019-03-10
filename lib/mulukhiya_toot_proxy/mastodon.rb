module MulukhiyaTootProxy
  class Mastodon < Ginseng::Mastodon
    include Package

    def initialize(uri, token = nil)
      super
      @uri = MastodonURI.parse(uri)
      @token = token
    end

    def account_id
      return account['id'].to_i
    end

    def account
      raise Ginseng::GatewayError, 'Invalid access token' unless @token
      @account ||= Mastodon.lookup_token_owner(@token)
      return @account
    end

    def self.lookup_token_owner(token)
      rows = Postgres.instance.execute('token_owner', {token: token})
      return rows.first if rows.present?
      return nil
    end
  end
end
