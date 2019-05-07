module MulukhiyaTootProxy
  class ResultNotificationHandler < NotificationHandler
    def notifiable?(body, headers)
      return UserConfigStorage.new[@mastodon.account_id]['/result/enable']
    rescue => e
      @logger.error(e)
      return false
    end

    def exec(body, headers = {})
      return unless @results.present?
      return unless notifiable?(body, headers)
      worker_name.constantize.perform_async({
        id: @mastodon.account_id,
        token: @mastodon.token,
        results: @results,
      })
      @result.to_json
    end
  end
end
