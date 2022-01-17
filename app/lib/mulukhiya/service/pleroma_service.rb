module Mulukhiya
  class PleromaService < Ginseng::Fediverse::PleromaService
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
      path = path.path if [File, Tempfile].map {|c| path.is_a?(c)}.any?
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
      payload = {file: {tempfile: MediaFile.download(uri)}}
      params[:filename] ||= File.basename(uri.path)
      Event.new(:pre_upload, params).dispatch(payload)
      response = upload(payload.dig(:file, :tempfile).path, params)
      Event.new(:post_upload, params).dispatch(payload)
      return response
    end

    def delete_attachment(attachment, params = {})
      attachment = attachment_class[attachment] if attachment.is_a?(String)
      return delete_status(attachment.status, params)
    end

    def search_status_id(status)
      case status
      in Pleroma::Status
        return status.id
      in Ginseng::URI
        response = @http.get(status, {follow_redirects: false})
        return response.headers['location'].match(%r{/notice/(.*)})[1]
      else
        return super
      end
    end

    def oauth_client(type = :default)
      return nil unless PleromaController.oauth_scopes(type)
      body = {
        client_name: PleromaController.oauth_client_name(type),
        website: config['/package/url'],
        redirect_uris: config['/pleroma/oauth/redirect_uri'],
        scopes: PleromaController.oauth_scopes(type).join(' '),
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
        redirect_uri: config['/pleroma/oauth/redirect_uri'],
        scope: PleromaController.oauth_scopes(type).join(' '),
      }
      return uri
    end

    def notify(account, message, options = {})
      options.deep_symbolize_keys!
      message = [account.acct.to_s, message].join("\n")
      return post(
        PleromaController.status_field => message.ellipsize(max_post_text_length),
        PleromaController.spoiler_field => options[:spoiler_text],
        PleromaController.visibility_field => PleromaController.visibility_name(:direct),
        'in_reply_to_id' => options.dig(:response, :id),
      )
    end

    def default_token
      return account_class.test_token
    end
  end
end
