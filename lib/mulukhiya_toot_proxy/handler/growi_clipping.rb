module MulukhiyaTootProxy
  class GrowiClippingHandler < Handler
    def exec(body, headers = {})
      return unless body['status'] =~ /#growi/i
      res = mastodon.growi.push({body: body['status']})
      body['status'] += "\n#{create_uri(res.data.path)}"
      increment!
    end

    def create_uri(path)
      @uri = MastodonURI.parse(UserConfigStorage.new[mastodon.account_id]['growi']['url'])
      @uri.path = path
      @uri = nil unless @uri.absolute?
      return @uri
    rescue
      return nil
    end
  end
end
