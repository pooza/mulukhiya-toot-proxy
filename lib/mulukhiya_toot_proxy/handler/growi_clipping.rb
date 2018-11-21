require 'crowi-client'

module MulukhiyaTootProxy
  class GrowiClippingHandler < Handler
    def exec(body, headers = {})
      return unless body['status'] =~ /#growi/mi
      growi.request(CPApiRequestPagesCreate.new({path: path, body: body['status']}))
    rescue => e
      raise ExternalServiceError, e.message
    end

    def path
      return '/%{package}/users/%{username}/%{date}' % {
        package: Package.name,
        username: mastodon.account['username'],
        date: Time.now.strftime('%Y/%m/%d/%H%M%S'),
      }
    end

    def growi
      userconfig = UserConfigStorage.new[mastodon.account_id]
      return CrowiClient.new({
        crowi_url: userconfig['growi']['url'],
        access_token: userconfig['growi']['token'],
      })
    end
  end
end
