module MulukhiyaTootProxy
  class ResultNotificationHandler < NotificationHandler
    def notifiable?(body)
      return UserConfigStorage.new[@mastodon.account_id]['/result/enable']
    rescue => e
      @logger.error(e)
      return false
    end

    def handle_post_toot(body, params = {})
      return unless @results.present?
      return unless notifiable?(body)
      worker_name.constantize.perform_async({
        id: @mastodon.account_id,
        token: @mastodon.token,
        results: @results,
      })
    end
  end
end
