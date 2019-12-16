require 'crowi-client'

module MulukhiyaTootProxy
  class GrowiClipper < CrowiClient
    def clip(params)
      params = {body: params.to_s} if params.is_a?(String)
      r = request(CPApiRequestPagesCreate.new(body: params[:body]))
      r = request(CPApiRequestPagesCreate.new(params)) if r.is_a?(CPInvalidRequest)
      raise Ginseng::GatewayError, r.msg if r.is_a?(CPInvalidRequest)
      return r
    end

    def self.create(params)
      account = Environment.account_class[params[:account_id]]
      return GrowiClipper.new(
        crowi_url: account.config['/growi/url'],
        access_token: account.config['/growi/token'],
      )
    rescue => e
      Logger.new.error(Ginseng::Error.create(e).to_h.merge(params: params))
      return nil
    end
  end
end
