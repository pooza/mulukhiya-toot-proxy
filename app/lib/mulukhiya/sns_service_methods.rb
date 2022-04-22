module Mulukhiya
  module SNSServiceMethods
    include SNSMethods

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
      params[:version] ||= 1
      Event.new(:pre_upload, params).dispatch(payload)
      response = upload(payload.dig(:file, :tempfile).path, params)
      Event.new(:post_upload, params).dispatch(payload)
      return response
    end

    def delete_attachment(attachment, params = {})
      attachment = attachment.id if attachment.is_a?(attachment_class)
      return super
    end

    def nodeinfo
      unless info = redis['nodeinfo']
        ttl = [config['/nodeinfo/cache/ttl'], 86_400].min
        info = super.to_json
        redis.setex('nodeinfo', ttl, info)
      end
      return JSON.parse(info)
    end

    def account
      @account ||= account_class.get(token:) rescue nil
      return @account
    end

    def access_token
      @access_token ||= access_token_class.get(token:) rescue nil
      return @access_token
    end

    def clear_oauth_client(type = :default)
      oauth_client_storage.unlink(type || :default)
    end

    def oauth_client_storage
      @oauth_client_storage ||= OAuthClientStorage.new
      return @oauth_client_storage
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end

    def default_token
      return account_class.test_token
    end
  end
end
