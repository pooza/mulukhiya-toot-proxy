require 'dropbox_api'
require 'digest/sha1'

module Mulukhiya
  class DropboxClipper < DropboxApi::Client
    def clip(params)
      params = {body: params.to_s} unless params.is_a?(Hash)
      src = File.join(Environment.dir, 'tmp/media', Digest::SHA1.hexdigest(params.to_s))
      dest = "/#{Time.now.strftime('%Y/%m/%d-%H%M%S')}.md"
      File.write(src, params[:body])
      return upload(dest, IO.read(src), {mode: :overwrite})
    rescue => e
      raise Ginseng::GatewayError, "Dropbox upload error #{e.message}", e.backtrace
    ensure
      File.unlink(src) if File.exist?(src)
    end

    def self.create(params)
      account = Environment.account_class[params[:account_id]]
      unless account.config['/dropbox/token']
        raise Ginseng::ConfigError, "Account #{account.acct} /dropbox/token undefined"
      end
      return DropboxClipper.new(account.config['/dropbox/token'])
    rescue Ginseng::ConfigError => e
      Logger.new.error(clipper: self.class.to_s, error: e.message)
      return nil
    rescue => e
      Logger.new.error(Ginseng::Error.create(e).to_h.merge(params: params))
      return nil
    end
  end
end
