require 'fileutils'

module Mulukhiya
  class PleromaService < Ginseng::Fediverse::PleromaService
    include Package
    attr_reader :token

    def initialize(uri = nil, token = nil)
      @config = Config.instance
      token ||= @config['/agent/test/token']
      super
    end

    def token=(token)
      @token = token
      @account = nil
    end

    def account
      @account ||= Environment.account_class.get(token: token)
      return @account
    rescue
      return nil
    end

    def bookmark(id, params = {})
      headers = params[:headers] || {}
      headers['Authorization'] ||= "Bearer #{token}"
      headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
      return @http.post("/api/v1/statuses/#{id}/bookmark", {
        body: '{}',
        headers: headers,
      })
    end

    def upload(path, params = {})
      if filename = params[:filename]
        dir = File.join(Environment.dir, 'tmp/media/upload', File.basename(path))
        FileUtils.mkdir_p(dir)
        file = MediaFile.new(path)
        filename += file.valid_extname unless file.valid_extname?
        dest = File.join(dir, filename)
        FileUtils.copy(path, dest)
        path = dest
      end
      return super
    ensure
      FileUtils.rm_rf(dir) if dir
    end

    def access_token
      return Environment.access_token_class.first(token: token) if token
      return nil
    end

    def oauth_client
      unless client = redis.get('oauth_client')
        r = @http.post('/api/v1/apps', {
          body: {
            client_name: package_class.name,
            website: @config['/package/url'],
            redirect_uris: @config['/pleroma/oauth/redirect_uri'],
            scopes: @config['/pleroma/oauth/scopes'].join(' '),
          }.to_json,
        })
        raise Ginseng::GatewayError, "Invalid response (#{r.code})" unless r.code == 200
        client = r.body
        redis.set('oauth_client', client)
      end
      return JSON.parse(client)
    end

    def clear_oauth_client
      Redis.new.unlink('oauth_client')
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end

    def filters
      return nil
    end

    def notify(account, message, response = nil)
      return post(
        PleromaController.status_field => [account.acct.to_s, message].join("\n"),
        'visibility' => PleromaController.visibility_name('direct'),
      )
    end
  end
end
