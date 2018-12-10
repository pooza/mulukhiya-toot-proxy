require 'crowi-client'

module MulukhiyaTootProxy
  class Growi < CrowiClient
    def push(body)
      request(CPApiRequestPagesCreate.new(body))
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

    def self.create_path(username)
      return '/%{package}/user/%{username}/%{date}' % {
        package: Package.short_name,
        username: username,
        date: Time.now.strftime('%Y/%m/%d/%H%M%S'),
      }
    end
  end
end
