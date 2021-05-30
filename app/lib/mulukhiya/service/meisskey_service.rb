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

    def delete_attachment(attachment, params = {})
      attachment = attachment.id if attachment.is_a?(attachment_class)
      return super
    end

    def oauth_client
      unless client = redis['oauth_client']
        client = http.post('/api/app/create', {
          body: {
            name: package_class.name,
            description: config['/package/description'],
            permission: MeisskeyController.oauth_scopes,
            callbackUrl: http.create_uri(config['/meisskey/oauth/callback/url']).to_s,
          },
        }).body
        redis['oauth_client'] = client
      end
      return JSON.parse(client)
    end

    def announcements(params = {})
      response = http.get('/api/meta', {
        body: {i: token}.to_json,
        headers: create_headers(params[:headers]),
      })
      return response['announcements'].map do |entry|
        {id: entry.to_json.adler32.to_s, title: entry['title'], text: entry['text']}
      end
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
