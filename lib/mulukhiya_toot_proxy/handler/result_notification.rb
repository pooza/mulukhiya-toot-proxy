module MulukhiyaTootProxy
  class ResultNotificationHandler < NotificationHandler
    def disable?
      return false unless @user_config["/handler/#{underscore_name}/disable"]
      return false unless @user_config['/handler/default/disable']
      return super
    end

    def notifiable?(body)
      return true
    end

    def handle_post_toot(body, params = {})
      return unless @results.present?
      return unless notifiable?(body)
      worker_class.perform_async({
        id: @mastodon.account_id,
        token: @mastodon.token,
        results: @results,
      })
    end
  end
end
