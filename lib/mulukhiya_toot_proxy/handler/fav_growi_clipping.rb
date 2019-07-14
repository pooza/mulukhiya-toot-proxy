module MulukhiyaTootProxy
  class FavGrowiClippingHandler < Handler
    def disable?
      return true if mastodon.account.config["/handler/#{underscore_name}/disable"].nil?
      return super
    end

    def handle_post_fav(body, params = {})
      uri = Toot.new(id: body['id'].to_i).uri
      GrowiClippingWorker.perform_async(
        uri: {href: uri.to_s, class: uri.class.to_s},
        account_id: mastodon.account.id,
      )
      @result.push(url: uri.to_s)
    end
  end
end
