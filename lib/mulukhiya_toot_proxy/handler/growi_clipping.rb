require 'crowi-client'
require 'addressable/uri'

module MulukhiyaTootProxy
  class GrowiClippingHandler < Handler
    def exec(body, headers = {})
      return unless body['status'] =~ /#growi/mi
      uri = create_uri
      mastodon.growi.push({path: uri.path, body: body['status']})
      body['status'] += "\n#{uri}"
    end

    def create_uri
      values = UserConfigStorage.new[mastodon.account_id]
      uri = MastodonURI.parse(values['growi']['url'])
      uri.path = '/%{package}/users/%{username}/%{date}' % {
        package: Package.name,
        username: mastodon.account['username'],
        date: Time.now.strftime('%Y/%m/%d/%H%M%S'),
      }
      return uri
    end
  end
end
