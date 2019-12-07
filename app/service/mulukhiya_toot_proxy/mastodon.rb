module MulukhiyaTootProxy
  class Mastodon < Ginseng::Mastodon
    include Package

    def initialize(uri = nil, token = nil)
      @config = Config.instance
      @logger = Logger.new
      uri ||= @config['/mastodon/url']
      token ||= @config['/test/token']
      super
      @uri = MastodonURI.parse(uri)
      @token = token
    end

    def search(keyword, params = {})
      params[:limit] ||= @config['/mastodon/search/limit']
      return super(keyword, params)
    end

    def filters(params = {})
      headers = params[:headers] || {}
      headers['Authorization'] ||= "Bearer #{@token}"
      headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
      return @http.get(create_uri('/api/v1/filters'), {headers: headers})
    end

    def register_filter(params)
      headers = params[:headers] || {}
      headers['Authorization'] ||= "Bearer #{@token}"
      headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
      return @http.post(create_uri('/api/v1/filters'), {
        body: {
          phrase: params[:phrase],
          context: params[:context] || [:home, :public],
        }.to_json,
        headers: headers,
      })
    end

    def unregister_filter(id, params = {})
      headers = params[:headers] || {}
      headers['Authorization'] ||= "Bearer #{@token}"
      headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
      return @http.delete(create_uri("/api/v1/filters/#{id}"), {
        body: '{}',
        headers: headers,
      })
    end

    def account
      raise Ginseng::GatewayError, 'Invalid access token' unless @token
      @account ||= Account.get(token: @token)
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
  end
end
