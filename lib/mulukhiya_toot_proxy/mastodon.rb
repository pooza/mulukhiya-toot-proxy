module MulukhiyaTootProxy
  class Mastodon < Ginseng::Mastodon
    include Package

    def initialize(uri, token = nil)
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

    def upload_remote_resource(uri)
      path = File.join(
        environment_class.constantize.dir,
        'tmp/media',
        Digest::SHA1.hexdigest(uri),
      )
      File.write(path, fetch(uri))
      return upload(path)
    ensure
      File.unlink(path) if File.exist?(path)
    end
  end
end
