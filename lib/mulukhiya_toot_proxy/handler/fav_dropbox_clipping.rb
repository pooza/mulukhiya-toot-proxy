module MulukhiyaTootProxy
  class FavDropboxClippingHandler < Handler
    def disable?
      return true if mastodon.account.config["/handler/#{underscore_name}/disable"].nil?
      return super
    end

    def handle_post_fav(body, params = {})
      uri = MastodonURI.parse(@config['/mastodon/url'])
      uri.path = "/web/statuses/#{body['id']}"
      DropboxClippingWorker.perform_async(
        uri: {href: uri.to_s, class: uri.class.to_s},
        account_id: mastodon.account.id,
      )
      @result.push(uri.to_s)
    end
  end
end
