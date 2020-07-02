module Mulukhiya
  class ResultNotificationHandler < Handler
    def disable?
      return true unless Environment.dbms_class.config?
      return false
    end

    def handle_post_toot(body, params = {})
      notify(reporter.to_h) if reporter.to_h.present?
    end

    def handle_post_webhook(body, params = {})
      notify(reporter.to_h) if reporter.to_h.present?
    end

    def handle_post_upload(body, params = {})
      notify(reporter.to_h) if reporter.to_h.present?
    end

    def handle_post_fav(body, params = {})
      notify(reporter.to_h) if reporter.to_h.present?
    end

    def handle_post_boost(body, params = {})
      notify(reporter.to_h) if reporter.to_h.present?
    end

    def handle_post_bookmark(body, params = {})
      notify(reporter.to_h) if reporter.to_h.present?
    end

    def handle_post_search(body, params = {})
      notify(reporter.to_h) if reporter.to_h.present?
    end
  end
end
