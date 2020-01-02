module MulukhiyaTootProxy
  class FavNotificationHandler < NotificationHandler
    def disable?
      return true unless Postgres.config?
      return super
    end

    def notifiable?(body)
      return false unless toot = Environment.status_class[body[message_key]]
      return false unless toot.local?
      return true
    rescue Ginseng::NotFoundError
      return false
    end

    def handle_post_fav(body, params = {})
      return unless notifiable?(body)
      worker_class.perform_async(
        account_id: sns.account.id,
        status_id: body['id'].to_i,
      )
      @result.push(status_id: body['id'].to_i)
    end
  end
end
