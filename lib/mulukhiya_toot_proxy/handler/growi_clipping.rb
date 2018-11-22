module MulukhiyaTootProxy
  class GrowiClippingHandler < Handler
    def exec(body, headers = {})
      return unless body['status'] =~ /#growi/mi
      mastodon.growi.push({path: uri.path, body: body['status']})
      body['status'] += "\n#{uri}"
    end

    def uri
      unless @uri
        values = UserConfigStorage.new[mastodon.account_id]
        @uri = MastodonURI.parse(values['growi']['url'])
        @uri.path = '/%{package}/users/%{username}/%{date}' % {
          package: Package.name,
          username: mastodon.account['username'],
          date: Time.now.strftime('%Y/%m/%d/%H%M%S'),
        }
      end
      return @uri
    end
  end
end
