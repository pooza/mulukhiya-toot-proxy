require 'fileutils'

module Mulukhiya
  class MisskeyService < Ginseng::Fediverse::MisskeyService
    include Package

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

    def account
      @account ||= Environment.account_class.get(token: token)
      return @account
    rescue
      return nil
    end

    def access_token
      return Environment.access_token_class.first(hash: token) if token
      return nil
    end

    def oauth_client
      unless client = redis.get('oauth_client')
        client = http.post('/api/app/create', {
          body: {
            name: package_class.name,
            description: @config['/package/description'],
            permission: @config['/misskey/oauth/permission'],
            callbackUrl: http.create_uri(@config['/misskey/oauth/callback_url']).to_s,
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
      note = {
        MisskeyController.status_field => message,
        'visibleUserIds' => [account.id],
        'visibility' => MisskeyController.visibility_name('direct'),
      }
      note['replyId'] = response['createdNote']['id'] if response
      return post(note)
    end

    def reset_token
      @token ||= default_token
    end

    private

    def default_token
      return @config['/agent/test/token']
    end
  end
end
