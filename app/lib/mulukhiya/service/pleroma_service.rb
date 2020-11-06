require 'fileutils'

module Mulukhiya
  class PleromaService < Ginseng::Fediverse::PleromaService
    include Package

    def account
      @account ||= Environment.account_class.get(token: token)
      return @account
    rescue
      return nil
    end

    def upload(path, params = {})
      if filename = params[:filename]
        dir = File.join(Environment.dir, 'tmp/media/upload', File.basename(path))
        FileUtils.mkdir_p(dir)
        file = MediaFile.new(path)
        filename += file.recommended_extname unless file.recommended_extname?
        dest = File.join(dir, filename)
        FileUtils.copy(path, dest)
        path = dest
      end
      params[:trim_times].times {ImageFile.new(path).trim!} if params&.dig(:trim_times)
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
        client = http.post('/api/v1/apps', {
          body: {
            client_name: package_class.name,
            website: @config['/package/url'],
            redirect_uris: @config['/pleroma/oauth/redirect_uri'],
            scopes: @config['/pleroma/oauth/scopes'].join(' '),
          }.to_json,
        }).body
        redis.set('oauth_client', client)
      end
      return JSON.parse(client)
    end

    def clear_oauth_client
      redis.unlink('oauth_client')
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end

    def notify(account, message, response = nil)
      toot = {
        PleromaController.status_field => [account.acct.to_s, message].join("\n"),
        'visibility' => PleromaController.visibility_name('direct'),
      }
      toot['in_reply_to_id'] = response['id'] if response
      return post(toot)
    end

    private

    def default_token
      return @config['/agent/test/token']
    end
  end
end
