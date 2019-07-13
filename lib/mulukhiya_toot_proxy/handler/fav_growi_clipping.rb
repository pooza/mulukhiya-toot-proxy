module MulukhiyaTootProxy
  class FavGrowiClippingHandler < Handler
    def disable?
      return true if mastodon.account.config["/handler/#{underscore_name}/disable"].nil?
      return super
    end

    def handle_post_fav(body, params = {})
      GrowiClippingWorker.perform_async(
        status_id: body['id'],
        account_id: mastodon.account.id,
      )
      @result.push(body['id'])
    end
  end
end
