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
      raise Ginseng::GatewayError, "Dropbox upload error (#{e.message})", e.backtrace
    ensure
      File.unlink(src) if File.exist?(src)
    end

    def self.create(params)
      logger = Logger.new
      account = Environment.account_class[params[:account_id]]
      unless account.user_config['/dropbox/token']
        raise Ginseng::ConfigError, "Account #{account.acct} /dropbox/token undefined"
      end
      return DropboxClipper.new(account.user_config['/dropbox/token'])
    rescue Ginseng::ConfigError => e
      logger.error(error: e)
      return nil
    rescue => e
      logger.error(error: e, params: params)
      return nil
    end
  end
end
