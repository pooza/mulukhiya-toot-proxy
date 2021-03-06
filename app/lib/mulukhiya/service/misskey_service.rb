module Mulukhiya
  class MisskeyService < Ginseng::Fediverse::MisskeyService
    include Package
    include SNSMethods
    include SNSServiceMethods

    alias info nodeinfo

    def upload(path, params = {})
      if filename = params[:filename]
        dir = File.join(Environment.dir, 'tmp/media/upload', path.adler32)
        FileUtils.mkdir_p(dir)
        file = MediaFile.new(path)
        dest = File.basename(filename, File.extname(filename)) + file.recommended_extname
        dest = File.join(dir, dest)
        FileUtils.copy(path, dest)
        path = dest
      end
      params[:trim_times].times {ImageFile.new(path).trim!} if params&.dig(:trim_times)
      return super
    ensure
      FileUtils.rm_rf(dir) if dir
    end

    def upload_remote_resource(uri, params = {})
      file = MediaFile.download(uri)
      payload = {file: {tempfile: file}}
      params[:filename] ||= File.basename(uri.path)
      Event.new(:pre_upload, params).dispatch(payload)
      response = upload(payload.dig(:file, :tempfile).path, params)
      Event.new(:post_upload, params).dispatch(payload)
      return response
    end

    def search_dupllicated_attachment(attachment, params = {})
      attachment = attachment.to_h[:md5] if attachment.is_a?(attachment_class)
      response = super
      return response if params[:response] == :raw
      return attachment_class[response.parsed_response.first['id']]
    end

    def delete_attachment(attachment, params = {})
      attachment = attachment.id if attachment.is_a?(attachment_class)
      return super
    end

    def oauth_client(type = :default)
      return nil unless MisskeyController.oauth_scopes(type)
      body = {
        name: MisskeyController.oauth_client_name(type),
        description: config['/package/description'],
        permission: MisskeyController.oauth_scopes(type),
      }
      unless client = oauth_client_storage[body]
        client = http.post('/api/app/create', {body: body}).body
        oauth_client_storage[body] = client
        redis.unlink('oauth_client')
      end
      return JSON.parse(client)
    end

    def oauth_uri(type = :default)
      return nil unless oauth_client(type)
      response = http.post('/api/auth/session/generate', {
        body: {appSecret: oauth_client(type)['secret']},
      })
      return Ginseng::URI.parse(response['url'])
    end

    def notify(account, message, response = nil)
      message = [account.acct.to_s, message.dup].join("\n")
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
      return account_class.test_token
    end
  end
end
