module Mulukhiya
  class DropboxClipper < DropboxApi::Client
    include Package

    def clip(params)
      params = {body: params.to_s} unless params.is_a?(Enumerable)
      src = File.join(Environment.dir, 'tmp/media', params.to_json.adler32)
      dest = "/#{Time.now.strftime('%Y/%m/%d-%H%M%S')}.md"
      File.write(src, params[:body])
      return upload(dest, File.read(src), {mode: :overwrite})
    rescue => e
      raise Ginseng::GatewayError, "Dropbox upload error (#{e.message})", e.backtrace
    ensure
      File.unlink(src) if File.exist?(src)
    end

    def self.create(params)
      account = Environment.account_class[params[:account_id]]
      unless token = account.user_config['/dropbox/token']
        raise Ginseng::ConfigError, "Account #{account.acct} /dropbox/token undefined"
      end
      return new(access_token: (token.decrypt rescue token))
    rescue Ginseng::ConfigError => e
      e.log
      return nil
    rescue => e
      e.log(params:)
      return nil
    end
  end
end
