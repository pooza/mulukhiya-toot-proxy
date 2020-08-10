module Mulukhiya
  class AnnictService
    def initialize(token = nil)
      @config = Config.instance
      @http = HTTP.new
      @http.base_uri = @config['/annict/url']
      @token = token
    end

    def auth(code)
      return @http.post('/oauth/token', {
        headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
        body: {
          'grant_type' => 'authorization_code',
          'redirect_uri' => @config['/mastodon/oauth/redirect_uri'],
          'client_id' => AnnictService.client_id,
          'client_secret' => AnnictService.client_secret,
          'code' => code,
        },
      })
    end

    def oauth_uri
      uri = @http.create_uri('/oauth/authorize')
      uri.query_values = {
        client_id: AnnictService.client_id,
        response_type: 'code',
        redirect_uri: @config['/annict/oauth/redirect_uri'],
        scope: @config['/annict/oauth/scopes'].join(' '),
      }
      return uri
    end

    def self.client_id
      return Config.instance['/annict/oauth/client/id']
    rescue Ginseng::ConfigError
      return nil
    end

    def self.client_secret
      return Config.instance['/annict/oauth/client/secret']
    rescue Ginseng::ConfigError
      return nil
    end

    def self.config?
      return false if client_id.nil?
      return false if client_secret.nil?
      return true
    end
  end
end
