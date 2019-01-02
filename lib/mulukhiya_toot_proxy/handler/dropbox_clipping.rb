module MulukhiyaTootProxy
  class DropboxClippingHandler < Handler
    def exec(body, headers = {})
      return unless body['status'] =~ /#dropbox/i
      DropboxClipper.create({account_id: mastodon.account_id}).clip({
        body: body['status'],
      })
      increment!
    end

    private

    def create_uri(path)
      uri = MastodonURI.parse(UserConfigStorage.new[mastodon.account_id]['/growi/url'])
      uri.path = path
      return nil unless uri.absolute?
      return uri
    rescue
      return nil
    end
  end
end
