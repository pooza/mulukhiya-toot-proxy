module MulukhiyaTootProxy
  class FavNotificationHandler < NotificationHandler
    def handle_post_fav(body, params = {})
      worker_class.perform_async(
        account_id: @mastodon.account.id,
        status_id: body['id'].to_i,
      )
      @result.push(body['id'].to_i)
    end
  end
end
