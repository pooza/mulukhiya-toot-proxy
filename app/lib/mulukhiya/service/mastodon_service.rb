module Mulukhiya
  class MastodonService < Ginseng::Fediverse::MastodonService
    include Package
    include SNSMethods
    include SNSServiceMethods

    alias info nodeinfo

    def post(body, params = {})
      response = super
      MediaCatalogUpdateWorker.perform_async if body[attachment_field].present?
      return response
    end

    alias toot post

    def upload(path, params = {})
      path = path.path if path.is_a?(File)
      path = path.path if path.is_a?(Tempfile)
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
    end

    def upload_remote_resource(uri, params = {})
      file = MediaFile.download(uri)
      payload = {file: {tempfile: file}}
      params[:version] ||= 1
      Event.new(:pre_upload, params).dispatch(payload)
      response = upload(payload.dig(:file, :tempfile).path, params)
      Event.new(:post_upload, params).dispatch(payload)
      return response
    end

    def delete_attachment(attachment, params = {})
      attachment = attachment_class[attachment] if attachment.is_a?(Integer)
      return delete_status(attachment.status, params) if attachment.status
    end

    def search_status_id(status)
      status = status.id if status.is_a?(status_class)
      return super
    end

    def search_attachment_id(attachment)
      attachment = attachment.id if attachment.is_a?(attachment_class)
      return super
    end

    def search(keyword, params = {})
      params[:limit] ||= config['/mastodon/search/limit']
      return super
    end

    def oauth_client(type = :default)
      return nil unless MastodonController.oauth_scopes(type)
      body = {
        client_name: MastodonController.oauth_client_name(type),
        website: config['/package/url'],
        redirect_uris: config['/mastodon/oauth/redirect_uri'],
        scopes: MastodonController.oauth_scopes(type).join(' '),
      }
      unless client = oauth_client_storage[body]
        client = http.post('/api/v1/apps', {body:}).body
        oauth_client_storage[body] = client
        redis.unlink('oauth_client')
      end
      return JSON.parse(client)
    end

    def oauth_uri(type = :default)
      return nil unless oauth_client(type)
      uri = create_uri('/oauth/authorize')
      uri.query_values = {
        client_id: oauth_client(type)['client_id'],
        response_type: 'code',
        redirect_uri: config['/mastodon/oauth/redirect_uri'],
        scope: MastodonController.oauth_scopes(type).join(' '),
      }
      return uri
    end

    def notify(account, message, options = {})
      options.deep_symbolize_keys!
      message = [account.acct.to_s, message].join("\n")
      return post(
        MastodonController.status_field => message.ellipsize(TootParser.new.max_length),
        MastodonController.spoiler_field => options[:spoiler_text],
        MastodonController.visibility_field => MastodonController.visibility_name(:direct),
        'in_reply_to_id' => options.dig(:response, :id),
      )
    end

    def default_token
      return account_class.test_token
    end
  end
end
