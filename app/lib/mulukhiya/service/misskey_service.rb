module Mulukhiya
  class MisskeyService < Ginseng::Misskey
    include Package
    attr_reader :token

    def initialize(uri = nil, token = nil)
      @config = Config.instance
      @logger = Logger.new
      @token = token || @config['/agent/test/token']
      @uri = NoteURI.parse(uri || @config['/misskey/url'])
      @mulukhiya_enable = false
      @http = http_class.new
      @http.base_uri = @uri
    end

    def token=(token)
      @token = token
      @account = nil
    end

    def account
      @account ||= Environment.account_class.get(token: @token)
      return @account
    rescue
      return nil
    end

    def fetch_note(id)
      return @http.get("/mulukhiya/note/#{id}")
    end

    alias toot note

    alias post note

    def oauth_client
      unless File.exist?(oauth_client_path)
        r = @http.post('/api/app/create', {
          body: {
            name: Package.name,
            description: @config['/package/description'],
            permission: @config['/misskey/oauth/permission'],
            callbackUrl: @http.create_uri(@config['/misskey/oauth/callback_url']).to_s,
          }.to_json,
        })
        File.write(oauth_client_path, r.parsed_response.to_json)
      end
      return JSON.parse(File.read(oauth_client_path))
    end

    def create_access_token(token)
      return Digest::SHA256.hexdigest(token + oauth_client['secret'])
    end

    def oauth_client_path
      return File.join(Environment.dir, 'tmp/cache/oauth_cilent.json')
    end

    def oauth_uri
      r = @http.post('/api/auth/session/generate', {
        body: {
          appSecret: oauth_client['secret'],
        }.to_json,
      })
      return Ginseng::URI.parse(r.parsed_response['url'])
    end

    def auth(token)
      return @http.post('/api/auth/session/userkey', {
        body: {
          appSecret: oauth_client['secret'],
          token: token,
        }.to_json,
      })
    end

    def notify(account, message)
      return note(
        MisskeyController.status_field => message,
        'visibleUserIds' => [account.id],
        'visibility' => MisskeyController.visibility_name('direct'),
      )
    end
  end
end
