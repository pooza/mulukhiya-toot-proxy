module MulukhiyaTootProxy
  class GrowiClippingHandler < Handler
    def exec(body, headers = {})
      return unless body['status'] =~ /#growi/i
      begin
        res = mastodon.growi.clip(body['status'])
      rescue ExternalServiceError
        res = mastodon.growi.clip({
          body: body['status'],
          path: GrowiClipper.create_path(mastodon.account['username']),
        })
      end
      body['status'] += "\n#{create_uri(res.data.path)}"
      increment!
    end

    private

    def create_uri(path)
      uri = MastodonURI.parse(UserConfigStorage.new[mastodon.account_id]['growi']['url'])
      uri.path = path
      return nil unless uri.absolute?
      return uri
    rescue
      return nil
    end
  end
end
