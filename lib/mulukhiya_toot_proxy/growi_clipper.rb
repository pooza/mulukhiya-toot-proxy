require 'crowi-client'

module MulukhiyaTootProxy
  class GrowiClipper < CrowiClient
    def clip(params)
      params = {body: params.to_s} if params.is_a?(String)
      res = request(CPApiRequestPagesCreate.new({body: params[:body]}))
      res = request(CPApiRequestPagesCreate.new(params)) if res.is_a?(CPInvalidRequest)
      raise ExternalServiceError, res.msg if res.is_a?(CPInvalidRequest)
      return res
    end

    def self.create(params)
      values = UserConfigStorage.new[params[:account_id]]
      return GrowiClipper.new({
        crowi_url: values['/growi/url'],
        access_token: values['/growi/token'],
      })
    rescue
      raise ExternalServiceError, 'GROWI not found'
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
