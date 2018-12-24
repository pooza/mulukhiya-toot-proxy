require 'crowi-client'

module MulukhiyaTootProxy
  class Growi < CrowiClient
    def push(body)
      res = request(CPApiRequestPagesCreate.new(body))
      raise RequestError, res.msg if res.is_a?(CPInvalidRequest)
      return res
    end

    def self.create(params)
      values = UserConfigStorage.new[params[:account_id]]
      return Growi.new({
        crowi_url: values['growi']['url'],
        access_token: values['growi']['token'],
      })
    rescue
      raise ExternalServiceError, 'GROWI not found'
    end
  end
end
