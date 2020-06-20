module Mulukhiya
  class PleromaService < Ginseng::Fediverse::Service
    include Package
    attr_reader :token

    def initialize(uri = nil, token = nil)
      @config = Config.instance
      token ||= @config['/agent/test/token']
      super
      @http.base_uri = Ginseng::URI.parse(uri || @config['/pleroma/url'])
    end

    def token=(token)
      @token = token
      @account = nil
    end

    def account
      unless @account
        @account = access_token.account
        @account.token = access_token.token
      end
      return @account
    rescue
      return nil
    end

    def access_token
      return Environment.access_token_class.first(token: token) if token
      return nil
    end

    def post(body, params = {})
      body = {status: body.to_s} unless body.is_a?(Hash)
      headers = params[:headers] || {}
      headers['Authorization'] ||= "Bearer #{@token}"
      headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
      return @http.post('/api/v1/statuses', {body: body.to_json, headers: headers})
    end

    alias toot post

    alias note post

    def upload(path, params = {})
      params[:version] ||= 1
      headers = params[:headers] || {}
      headers['Authorization'] ||= "Bearer #{@token}"
      headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
      response = @http.upload("/api/v#{params[:version]}/media", path, headers)
      return response if params[:response] == :raw
      return JSON.parse(response.body)['id'].to_i
    end

    def filters
      return nil
    end

    def oauth_client
      unless client = redis.get('oauth_client')
        if File.exist?(oauth_client_path)
          client = File.read(oauth_client_path)
          File.delete(oauth_client_path)
        else
          r = @http.post('/api/v1/apps', {
            body: {
              client_name: package_class.name,
              website: @config['/package/url'],
              redirect_uris: @config['/pleroma/oauth/redirect_uri'],
              scopes: @config['/pleroma/oauth/scopes'].join(' '),
            }.to_json,
          })
          raise "Invalid response (#{r.code})" unless r.code == 200
          client = r.body
        end
        redis.set('oauth_client', client)
      end
      return JSON.parse(client)
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end

    def oauth_uri
      uri = @http.create_uri('/oauth/authorize')
      uri.query_values = {
        client_id: oauth_client['client_id'],
        response_type: 'code',
        redirect_uri: @config['/pleroma/oauth/redirect_uri'],
        scope: @config['/pleroma/oauth/scopes'].join(' '),
      }
      return uri
    end

    def auth(code)
      return @http.post('/oauth/token', {
        headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
        body: {
          'grant_type' => 'authorization_code',
          'redirect_uri' => @config['/pleroma/oauth/redirect_uri'],
          'client_id' => oauth_client['client_id'],
          'client_secret' => oauth_client['client_secret'],
          'code' => code,
        },
      })
    end

    def clear_oauth_client
      File.unlink(oauth_client_path) if File.exist?(oauth_client_path)
      Redis.new.unlink('oauth_client')
    end

    def notify(account, message)
      return post(
        PleromaController.status_field => [account.acct.to_s, message].join("\n"),
        'visibility' => PleromaController.visibility_name('direct'),
      )
    end

    def create_uri(href = '/api/v1/statuses')
      return @http.create_uri(href)
    end
  end
end
