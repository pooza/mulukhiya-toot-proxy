require 'crowi-client'

module MulukhiyaTootProxy
  class GrowiClippingHandler < Handler
    def exec(body, headers = {})
      return unless body['status'] =~ /#growi/m
      growi.request(CPApiRequestPagesCreate.new({
        path: "/user/pooza/メモ/#{Date.today.strftime('%Y/%m/%d')}",
        body: body['status'],
      }))
    end

    def growi
      storage = UserConfigStorage.new
      userconfig = storage[mastodon.account_id]
      return CrowiClient.new({
        crowi_url: userconfig['growi']['servers'].first['url'],
        access_token: userconfig['growi']['servers'].first['token'],
      })
    rescue => e
      return ExternalServiceError, e.message
    end
  end
end
