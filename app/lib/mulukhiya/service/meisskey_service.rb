module Mulukhiya
  class MeisskeyService < Ginseng::Fediverse::MeisskeyService
    include Package
    include ServiceMethods

    alias info nodeinfo

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

    def oauth_client
      unless client = redis.get('oauth_client')
        client = http.post('/api/app/create', {
          body: {
            name: package_class.name,
            description: config['/package/description'],
            permission: config['/meisskey/oauth/scopes'],
            callbackUrl: http.create_uri(config['/meisskey/oauth/callback_url']).to_s,
          },
        }).body
        redis.set('oauth_client', client)
      end
      return JSON.parse(client)
    end

    def notify(account, message, response = nil)
      message = [account.acct.to_s, message.clone].join("\n")
      message.ellipsize!(NoteParser.new.max_length)
      status = {
        MisskeyController.status_field => message,
        'visibleUserIds' => [account.id],
        'visibility' => MisskeyController.visibility_name('direct'),
      }
      status['replyId'] = response['createdNote']['id'] if response
      return post(status)
    end

    def default_token
      return Environment.account_class.test_token
    end
  end
end
