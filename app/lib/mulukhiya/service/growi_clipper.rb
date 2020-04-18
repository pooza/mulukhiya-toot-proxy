module Mulukhiya
  class GrowiClipper
    GRANT_PUBLIC = 1
    GRANT_RESTRICTED = 2
    GRANT_SPECIFIED = 3
    GRANT_OWNER = 4

    def initialize(params = {})
      uri = params[:uri]
      uri = Ginseng::URI.parse(uri.to_s) unless uri.is_a?(Ginseng::URI)
      @token = params[:token]
      @http = HTTP.new
      @http.base_uri = uri
    end

    def clip(params)
      params = {body: params.to_s} if params.is_a?(String)
      params[:access_token] ||= @token
      params[:grant] ||= GRANT_OWNER
      r = @http.post('/_api/pages.create', {body: params.delete_if {|k, v| k == :path}.to_json})
      r = @http.post('/_api/pages.create', {body: params.to_json}) unless r.code == 200
      raise Ginseng::GatewayError, "Bad response #{r.code}" unless r.code == 200
      return r
    end

    def self.create(params)
      account = Environment.account_class[params[:account_id]]
      unless account.config['/growi/url']
        raise Ginseng::ConfigError, "Account #{account.acct} /growi/url undefined"
      end
      unless account.config['/growi/token']
        raise Ginseng::ConfigError, "Account #{account.acct} /growi/token undefined"
      end
      return GrowiClipper.new(
        uri: account.config['/growi/url'],
        token: account.config['/growi/token'],
      )
    rescue Ginseng::ConfigError => e
      Logger.new.error(clipper: self.class.to_s, error: e.message)
      return nil
    rescue => e
      Logger.new.error(Ginseng::Error.create(e).to_h.merge(params: params))
      return nil
    end
  end
end
