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
    rescue Dropbox::ApiError => ex
      raise Ginseng::GatewayError, "Dropbox upload error (#{ex.message})"
    ensure
      File.unlink(src) if File.exist?(src)
    end

    def self.create(params)
      return DropboxClipper.new(
        UserConfigStorage.new[params[:account_id]]['/dropbox/token'],
      )
    rescue => ex
      raise Ginseng::GatewayError, "Dropbox auth error (#{ex.message})"
    end
  end
end
