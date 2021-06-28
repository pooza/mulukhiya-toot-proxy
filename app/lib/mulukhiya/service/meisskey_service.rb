module Mulukhiya
  class MeisskeyService < Ginseng::Fediverse::MeisskeyService
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
      envelope = {file: {tempfile: file}}
      params[:reporter] ||= Reporter.new
      Event.new(:pre_upload, {reporter: params[:reporter], sns: self}).dispatch(envelope)
      id = upload(file.path, {
        response: :id,
        filename: File.basename(uri.path),
        trim_times: params[:trim_times],
      })
      Event.new(:post_upload, {reporter: params[:reporter], sns: self}).dispatch(envelope)
      return id
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
    ensure
      File.unlink(file&.path) if File.exist?(file&.path)
    end

    def delete_attachment(attachment, params = {})
      attachment = attachment.id if attachment.is_a?(attachment_class)
      return super
    end

    def oauth_client(type = :default)
      return nil unless MeisskeyController.oauth_scopes(type)
      body = {
        name: MeisskeyController.oauth_client_name(type),
        description: config['/package/description'],
        permission: MeisskeyController.oauth_scopes(type),
        callbackUrl: http.create_uri(config['/meisskey/oauth/callback/url']).to_s,
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
      return account_class.test_token
    end
  end
end
