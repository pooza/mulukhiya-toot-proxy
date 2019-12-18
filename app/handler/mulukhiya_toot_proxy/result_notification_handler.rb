module MulukhiyaTootProxy
  class ResultNotificationHandler < NotificationHandler
    def disable?
      return true unless Postgres.config?
      return true if sns.account.config['/handler/result_notification/disable'].nil?
      return true if sns.account.disable?(underscore_name)
      return true if @config.disable?(underscore_name)
      return false
    rescue Ginseng::ConfigError
      return false
    end

    def notifiable?(body)
      return false unless sns.account.config['/slack/webhook'].present?
      return results.present?
    end

    def handle_post_toot(body, params = {})
      return unless notifiable?(body)
      worker_class.perform_async(account_id: sns.account.id, results: results)
    end

    def handle_post_webhook(body, params = {})
      return unless notifiable?(body)
      worker_class.perform_async(account_id: sns.account.id, results: results)
    end

    def handle_post_upload(body, params = {})
      return unless notifiable?(body)
      worker_class.perform_async(account_id: sns.account.id, results: results)
    end

    def handle_post_fav(body, params = {})
      return unless notifiable?(body)
      worker_class.perform_async(account_id: sns.account.id, results: results)
    end

    def handle_post_boost(body, params = {})
      return unless notifiable?(body)
      worker_class.perform_async(account_id: sns.account.id, results: results)
    end

    def handle_post_search(body, params = {})
      return unless notifiable?(body)
      worker_class.perform_async(account_id: sns.account.id, results: results)
    end
  end
end
