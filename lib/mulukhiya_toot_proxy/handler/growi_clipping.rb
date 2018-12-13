module MulukhiyaTootProxy
  class GrowiClippingHandler < Handler
    def exec(body, headers = {})
      return unless body['status'] =~ /#growi/i
      mastodon.growi.push({path: uri.path, body: body['status']})
      body['status'] += "\n#{uri}"
      increment!
    end

    def uri
      unless @uri
        values = UserConfigStorage.new[mastodon.account_id]
        @uri = MastodonURI.parse(values['growi']['url'])
        @uri.path = Growi.create_path(mastodon.account['username'])
        @uri = nil unless @uri.absolute?
      end
      return @uri
    rescue
      return nil
    end
  end
end
