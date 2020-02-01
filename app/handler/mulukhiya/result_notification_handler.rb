module Mulukhiya
  class ResultNotificationHandler < Handler
    def handle_post_toot(body, params = {})
      notify if notifiable?
    end

    def handle_post_webhook(body, params = {})
      notify if notifiable?
    end

    def handle_post_upload(body, params = {})
      notify if notifiable?
    end

    def handle_post_fav(body, params = {})
      notify if notifiable?
    end

    def handle_post_boost(body, params = {})
      notify if notifiable?
    end

    def handle_post_bookmark(body, params = {})
      notify if notifiable?
    end

    def handle_post_search(body, params = {})
      notify if notifiable?
    end

    def notifiable?
      return results.present?
    end

    def notify
      Environment.info_agent&.notify(results.to_s)
    end
  end
end
