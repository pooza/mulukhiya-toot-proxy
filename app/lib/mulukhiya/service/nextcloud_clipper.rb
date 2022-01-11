module Mulukhiya
  class NextcloudClipper
    include Package

    def initialize(params)
      Nextcloud::Ruby.configure do |nextcloud|
        nextcloud.dav_url = params[:url]
        nextcloud.username = params[:user]
        nextcloud.password = (params[:password].decrypt rescue params[:password])
      end
    end

    def clip(params)
      params = {body: params.to_s} unless params.is_a?(Enumerable)
      src = File.join(Environment.dir, 'tmp/media', params.to_json.adler32)
      dest = "/#{Time.now.strftime('%Y/%m/%d-%H%M%S')}.md"
      File.write(src, params[:body])
      return upload(dest, File.read(src))
    rescue => e
      raise Ginseng::GatewayError, "Nextcloud upload error (#{e.message})", e.backtrace
    ensure
      File.unlink(src) if File.exist?(src)
    end

    def upload(path, file)
    end
  end
end
