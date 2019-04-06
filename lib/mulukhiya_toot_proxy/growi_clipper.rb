require 'crowi-client'

module MulukhiyaTootProxy
  class GrowiClipper < CrowiClient
    def clip(params)
      params = {body: params.to_s} if params.is_a?(String)
      res = request(CPApiRequestPagesCreate.new({body: params[:body]}))
      res = request(CPApiRequestPagesCreate.new(params)) if res.is_a?(CPInvalidRequest)
      raise Ginseng::GatewayError, res.msg if res.is_a?(CPInvalidRequest)
      return res
    end

    def self.create(params)
      user_config = UserConfigStorage.new[params[:account_id]]
      return GrowiClipper.new({
        crowi_url: user_config['/growi/url'],
        access_token: user_config['/growi/token'],
      })
    rescue => e
      raise Ginseng::GatewayError, "GROWI initialize error (#{e.message})"
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
