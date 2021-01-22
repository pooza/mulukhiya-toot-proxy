module Mulukhiya
  class PleromaService < Ginseng::Fediverse::PleromaService
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
        client = http.post('/api/v1/apps', {
          body: {
            client_name: package_class.name,
            website: config['/package/url'],
            redirect_uris: config['/pleroma/oauth/redirect_uri'],
            scopes: config['/pleroma/oauth/scopes'].join(' '),
          },
        }).body
        redis.set('oauth_client', client)
      end
      return JSON.parse(client)
    end

    def notify(account, message, response = nil)
      message = [account.acct.to_s, message.clone].join("\n")
      message.ellipsize!(TootParser.new.max_length)
      status = {
        PleromaController.status_field => message,
        'visibility' => PleromaController.visibility_name('direct'),
      }
      status['in_reply_to_id'] = response['id'] if response
      return post(status)
    end

    def default_token
      return Environment.account_class.test_token
    end
  end
end
