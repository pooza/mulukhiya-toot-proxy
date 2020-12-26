require 'fileutils'

module Mulukhiya
  class MisskeyService < Ginseng::Fediverse::MisskeyService
    include Package

    def nodeinfo
      ttl = [config['/nodeinfo/cache/ttl'], 86_400].min
      redis.setex('nodeinfo', ttl, super.to_json)
      return JSON.parse(redis.get('nodeinfo'))
    end

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

    def antennas(params = {})
      headers = params[:headers] || {}
      headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
      response = http.post('/api/antennas/list', {
        body: {i: token}.to_json,
        headers: headers,
      })
      return response.parsed_response
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

    def search_dupllicated_attachment(attachment, params = {})
      attachment = Environment.attachment_class[attachment] if attachment.is_a?(String)
      headers = params[:headers] || {}
      headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
      response = http.post('/api/drive/files/find-by-hash', {
        body: {i: token, md5: attachment.to_h[:md5]}.to_json,
        headers: headers,
      })
      return Environment.attachment_class[response.parsed_response.first['id']]
    end

    def delete_attachment(attachment, params = {})
      attachment = Environment.attachment_class[attachment] if attachment.is_a?(String)
      headers = params[:headers] || {}
      headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
      return http.post('/api/drive/files/delete', {
        body: {i: token, fileId: attachment.id}.to_json,
        headers: headers,
      })
    end

    def oauth_client
      unless client = redis.get('oauth_client')
        client = http.post('/api/app/create', {
          body: {
            name: package_class.name,
            description: config['/package/description'],
            permission: config['/misskey/oauth/scopes'],
            callbackUrl: http.create_uri(config['/misskey/oauth/callback_url']).to_s,
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
      return config['/agent/test/token']
    end
  end
end
