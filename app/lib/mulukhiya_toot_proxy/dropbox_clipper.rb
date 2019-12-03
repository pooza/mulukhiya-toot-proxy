require 'dropbox_api'
require 'digest/sha1'

module MulukhiyaTootProxy
  class DropboxClipper < DropboxApi::Client
    def clip(params)
      src = File.join(Environment.dir, 'tmp/media', Digest::SHA1.hexdigest(params.to_s))
      dest = "/#{Time.now.strftime('%Y/%m/%d-%H%M%S')}.md"
      File.write(src, params[:body])
      upload(dest, IO.read(src), {mode: :overwrite})
    rescue => e
      raise Ginseng::GatewayError, 'Dropbox upload error', e.backtrace
    ensure
      File.unlink(src) if File.exist?(src)
    end

    def self.create(params)
      account = Account.new(id: params[:account_id])
      return DropboxClipper.new(account.config['/dropbox/token'])
    rescue => e
      Logger.new.error(Ginseng::Error.create(e).to_h.merge(params: params))
      return nil
    end
  end
end
