module MulukhiyaTootProxy
  class FavDropboxClippingHandler < Handler
    def handle_post_fav(body, params = {})
      uri = Toot.new(id: body['id'].to_i).uri
      DropboxClippingWorker.perform_async(
        uri: {href: uri.to_s, class: uri.class.to_s},
        account_id: mastodon.account.id,
      )
      @result.push(url: uri.to_s)
    end
  end
end
