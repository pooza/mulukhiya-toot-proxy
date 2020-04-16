require 'crowi-client'

module Mulukhiya
  class GrowiClipper < CrowiClient
    def clip(params)
      params = {body: params.to_s} if params.is_a?(String)
      params[:grant] ||= CrowiPage::GRANT_OWNER
      r = request(CPApiRequestPagesCreate.new(body: params[:body], grant: params[:grant]))
      r = request(CPApiRequestPagesCreate.new(params)) if r.is_a?(CPInvalidRequest)
      raise Ginseng::GatewayError, r.msg if r.is_a?(CPInvalidRequest)
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
        crowi_url: account.config['/growi/url'],
        access_token: account.config['/growi/token'],
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
