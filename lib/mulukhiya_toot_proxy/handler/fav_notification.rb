module MulukhiyaTootProxy
  class FavNotificationHandler < NotificationHandler
    def notifiable?(body)
      return Toot.new(id: body['id'].to_i).present?
    rescue Ginseng::NotFoundError
      return false
    end

    def handle_post_fav(body, params = {})
      return unless notifiable?(body)
      worker_class.perform_async(
        account_id: mastodon.account.id,
        status_id: body['id'].to_i,
      )
      @result.push(body['id'].to_i)
    end
  end
end
