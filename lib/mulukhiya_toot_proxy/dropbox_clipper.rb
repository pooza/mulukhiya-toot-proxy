require 'dropbox'
require 'digest/sha1'

module MulukhiyaTootProxy
  class DropboxClipper < Dropbox::Client
    def clip(params)
      src = File.join(Environment.dir, 'tmp/media', Digest::SHA1.hexdigest(params.to_s))
      File.write(src, params[:body])
      File.open(src) do |file|
        upload("/#{Time.now.strftime('%Y/%m/%d-%H%M%S')}.md", file.read)
      end
    rescue Dropbox::ApiError => e
      raise Ginseng::GatewayError, "Dropbox upload error (#{e.message})"
    ensure
      File.unlink(src) if File.exist?(src)
    end

    def self.create(params)
      return DropboxClipper.new(
        UserConfigStorage.new[params[:account_id]]['/dropbox/token'],
      )
    rescue => e
      raise Ginseng::GatewayError, "Dropbox auth error (#{e.message})"
    end
  end
end
