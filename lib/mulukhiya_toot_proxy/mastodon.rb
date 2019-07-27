module MulukhiyaTootProxy
  class Mastodon < Ginseng::Mastodon
    include Package
    attr_accessor :token

    def initialize(uri = nil, token = nil)
      @config = Config.instance
      @logger = Logger.new
      uri ||= @config['/mastodon/url']
      token ||= @config['/test/token']
      super
      @uri = MastodonURI.parse(uri)
      @token = token
    end

    def upload(path, params = {})
      params[:headers] ||= {
        'Authorization' => "Bearer #{@token}",
        'X-Mulukhiya' => Package.name,
      }
      return super(path, params)
    end

    def favourite(id, params = {})
      headers = params[:headers] || {}
      headers['Authorization'] ||= "Bearer #{@token}"
      headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
      return @http.post(create_uri("/api/v1/statuses/#{id}/favourite"), {
        body: '{}',
        headers: headers,
      })
    end

    alias fav favourite

    def reblog(id, params = {})
      headers = params[:headers] || {}
      headers['Authorization'] ||= "Bearer #{@token}"
      headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
      return @http.post(create_uri("/api/v1/statuses/#{id}/reblog"), {
        body: '{}',
        headers: headers,
      })
    end

    alias boost reblog

    def account
      raise Ginseng::GatewayError, 'Invalid access token' unless @token
      @account ||= Account.new(token: @token)
      return @account
    end

    def oauth_client
      unless File.exist?(oauth_client_path)
        body = {
          client_name: Package.name,
          website: @config['/package/url'],
          redirect_uris: @config['/mastodon/oauth/redirect_uri'],
          scopes: @config['/mastodon/oauth/scopes'].join(' '),
        }
        r = @http.post(create_uri('/api/v1/apps'), {body: body.to_json})
        File.write(oauth_client_path, r.parsed_response.to_json)
      end
      return JSON.parse(File.read(oauth_client_path))
    end

    def oauth_client_path
      return File.join(Environment.dir, 'tmp/cache/oauth_cilent.json')
    end

    def oauth_uri
      uri = create_uri('/oauth/authorize')
      uri.query_values = {
        client_id: oauth_client['client_id'],
        response_type: 'code',
        redirect_uri: @config['/mastodon/oauth/redirect_uri'],
        scope: @config['/mastodon/oauth/scopes'].join(' '),
      }
      return uri
    end

    def auth(code)
      return @http.post(create_uri('/oauth/token'), {
        headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
        body: {
          'grant_type' => 'authorization_code',
          'redirect_uri' => @config['/mastodon/oauth/redirect_uri'],
          'client_id' => oauth_client['client_id'],
          'client_secret' => oauth_client['client_secret'],
          'code' => code,
        },
      })
    end

    def self.lookup_attachment(id)
      rows = Postgres.instance.execute('attachment', {id: id})
      return rows.first.with_indifferent_access if rows.present?
      return nil
    end

    def self.lookup_account(id)
      rows = Postgres.instance.execute('account', {id: id})
      return rows.first.with_indifferent_access if rows.present?
      return nil
    end

    def self.lookup_toot(id)
      rows = Postgres.instance.execute('toot', {id: id})
      return rows.first.with_indifferent_access if rows.present?
      return nil
    end

    def self.lookup_token_owner(token)
      rows = Postgres.instance.execute('token_owner', {token: token})
      return rows.first.with_indifferent_access if rows.present?
      return nil
    end
  end
end
