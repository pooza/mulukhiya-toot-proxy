module Mulukhiya
  class BoostNotificationHandler < NotificationHandler
    def disable?
      return true unless Postgres.config?
      return super
    end

    def notifiable?(body)
      return false unless status = Environment.status_class[body[status_key]]
      return false unless status.local?
      return true
    rescue Ginseng::NotFoundError
      return false
    end

    def handle_post_boost(body, params = {})
      return unless notifiable?(body)
      worker_class.perform_async(account_id: sns.account.id, status_id: body[status_key])
      @result.push(status_id: body[status_key])
    end
  end
end
