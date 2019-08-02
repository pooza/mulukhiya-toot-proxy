module MulukhiyaTootProxy
  class ResultNotificationHandler < NotificationHandler
    def notifiable?(body)
      return results.present?
    end

    def handle_post_toot(body, params = {})
      return unless notifiable?(body)
      worker_class.perform_async(account_id: mastodon.account.id, results: results)
    end

    def handle_post_webhook(body, params = {})
      return unless notifiable?(body)
      worker_class.perform_async(account_id: mastodon.account.id, results: results)
    end

    def handle_post_upload(body, params = {})
      return unless notifiable?(body)
      worker_class.perform_async(account_id: mastodon.account.id, results: results)
    end

    def handle_post_fav(body, params = {})
      return unless notifiable?(body)
      worker_class.perform_async(account_id: mastodon.account.id, results: results)
    end

    def handle_post_boost(body, params = {})
      return unless notifiable?(body)
      worker_class.perform_async(account_id: mastodon.account.id, results: results)
    end

    def handle_post_search(body, params = {})
      return unless notifiable?(body)
      worker_class.perform_async(account_id: mastodon.account.id, results: results)
    end
  end
end
