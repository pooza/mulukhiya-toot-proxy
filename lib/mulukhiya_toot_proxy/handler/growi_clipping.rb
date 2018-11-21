require 'crowi-client'
require 'addressable/uri'

module MulukhiyaTootProxy
  class GrowiClippingHandler < Handler
    def exec(body, headers = {})
      return unless body['status'] =~ /#growi/mi
      growi.request(CPApiRequestPagesCreate.new({path: path, body: body['status']}))
      body['status'] += "\n#{uri}"
    end

    def uri
      unless @uri
        values = UserConfigStorage.new[mastodon.account_id]
        uri = Addressable::URI.parse(values['growi']['url'])
        uri.path = path
      end
      return uri
    end

    def path
      return '/%{package}/users/%{username}/%{date}' % {
        package: Package.name,
        username: mastodon.account['username'],
        date: Time.now.strftime('%Y/%m/%d/%H%M%S'),
      }
    end

    def growi
      unless @growi
        values = UserConfigStorage.new[mastodon.account_id]
        return CrowiClient.new({
          crowi_url: values['growi']['url'],
          access_token: values['growi']['token'],
        })
      end
      return @growi
    end
  end
end
