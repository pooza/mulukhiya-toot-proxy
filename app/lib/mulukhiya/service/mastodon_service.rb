module Mulukhiya
  class MastodonService < Ginseng::Mastodon
    include Package
    attr_reader :token

    def initialize(uri = nil, token = nil)
      @config = Config.instance
      @logger = Logger.new
      uri ||= @config['/mastodon/url']
      token ||= @config['/agent/test/token']
      super
      @uri = TootURI.parse(uri)
      @token = token
    end

    alias note toot

    alias post toot

    def upload(path, params = {})
      headers = params[:headers] || {}
      headers['Authorization'] ||= "Bearer #{@token}"
      headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
      response = @http.upload(create_uri('/api/v2/media'), path, headers)
      return response if params[:response] == :raw
      return JSON.parse(response.body)['id'].to_i
    end

    def search(keyword, params = {})
      params[:limit] ||= @config['/mastodon/search/limit']
      return super(keyword, params)
    end

    def account
      @account ||= Environment.account_class.get(token: @token)
      return @account
    rescue
      return nil
    end

    def token=(token)
      @token = token
      @account = nil
    end

    def oauth_client
      unless File.exist?(oauth_client_path)
        r = @http.post(create_uri('/api/v1/apps'), {
          body: {
            client_name: Package.name,
            website: @config['/package/url'],
            redirect_uris: @config['/mastodon/oauth/redirect_uri'],
            scopes: @config['/mastodon/oauth/scopes'].join(' '),
          }.to_json,
        })
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

    def notify(account, message)
      return toot(
        MastodonController.status_field => [account.acct.to_s, message].join("\n"),
        'visibility' => MastodonController.visibility_name('direct'),
      )
    end
  end
end
