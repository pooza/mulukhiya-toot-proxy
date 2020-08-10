module Mulukhiya
  class AnnictService
    def initialize(token = nil)
      @config = Config.instance
      @http = HTTP.new
      @http.base_uri = 'https://annict.jp'
      @token = token
    end

    def auth(code)
      return @http.post('/oauth/token', {
        headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
        body: {
          'grant_type' => 'authorization_code',
          'redirect_uri' => @config['/mastodon/oauth/redirect_uri'],
          'client_id' => @config['/annict/oauth/client/id'],
          'client_secret' => @config['/annict/oauth/client/secret'],
          'code' => code,
        },
      })
    end

    def oauth_uri
      uri = @http.create_uri('/oauth/authorize')
      uri.query_values = {
        client_id: @config['/annict/oauth/client/id'],
        response_type: 'code',
        redirect_uri: @config['/annict/oauth/redirect_uri'],
        scope: @config['/annict/oauth/scopes'].join(' '),
      }
      return uri
    end
  end
end
