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
      unless @account
        rows = Postgres.instance.execute('token_owner', {token: @token})
        @account = rows.first if rows.present?
      end
      return @account
    end
  end
end
