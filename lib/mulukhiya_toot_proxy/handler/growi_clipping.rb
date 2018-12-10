module MulukhiyaTootProxy
  class GrowiClippingHandler < Handler
    def exec(body, headers = {})
      return unless body['status'] =~ /#growi/mi
      mastodon.growi.push({path: uri.path, body: body['status']})
      body['status'] += "\n#{uri}"
      increment!
    end

    def uri
      unless @uri
        values = UserConfigStorage.new[mastodon.account_id]
        @uri = MastodonURI.parse(values['growi']['url'])
        @uri.path = Growi.create_path(mastodon.account['username'])
      end
      return @uri
    end
  end
end
