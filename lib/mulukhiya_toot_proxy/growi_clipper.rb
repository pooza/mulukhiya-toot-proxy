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
      account = Account.new(id: params[:account_id])
      return GrowiClipper.new(
        crowi_url: account.config['/growi/url'],
        access_token: account.config['/growi/token'],
      )
    rescue => e
      Logger.new.error(e)
      return nil
    end

    def self.create_path(username)
      return File.join(
        '/',
        Package.short_name,
        'user',
        username,
        Time.now.strftime('%Y/%m/%d/%H%M%S'),
      )
    end
  end
end
