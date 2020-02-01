module Mulukhiya
  class ResultNotificationHandler < Handler
    def handle_post_toot(body, params = {})
      notify
    end

    def handle_post_webhook(body, params = {})
      notify
    end

    def handle_post_upload(body, params = {})
      notify
    end

    def handle_post_fav(body, params = {})
      notify
    end

    def handle_post_boost(body, params = {})
      notify
    end

    def handle_post_bookmark(body, params = {})
      notify
    end

    def handle_post_search(body, params = {})
      notify
    end

    def notify
      return unless results.to_h.present?
      Environment.info_agent&.notify(sns.account, results.to_s)
    end
  end
end
