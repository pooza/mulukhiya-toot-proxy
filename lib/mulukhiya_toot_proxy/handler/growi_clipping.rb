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
      return "/%s/users/%s/%s" % [
        Package.name,
        mastodon.account['username'],
        Time.now.strftime('%Y/%m/%d/%H%M%S'),
      ]
    end

    def growi
      userconfig = UserConfigStorage.new[mastodon.account_id]
      return CrowiClient.new({
        crowi_url: userconfig['growi']['servers'].first['url'],
        access_token: userconfig['growi']['servers'].first['token'],
      })
    end
  end
end
