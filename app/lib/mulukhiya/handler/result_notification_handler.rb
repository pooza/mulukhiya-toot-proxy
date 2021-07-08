module Mulukhiya
  class ResultNotificationHandler < Handler
    def disable?
      return true unless Environment.dbms_class.config?
      return false
    end

    def handle_post_toot(payload, params = {})
      notify(reporter.to_h, reporter.response) if reporter.to_h.present?
    end

    def handle_post_webhook(payload, params = {})
      notify(reporter.to_h, reporter.response) if reporter.to_h.present?
    end

    def handle_post_upload(payload, params = {})
      notify(reporter.to_h) if reporter.to_h.present?
    end

    def handle_post_fav(payload, params = {})
      notify(reporter.to_h) if reporter.to_h.present?
    end

    def handle_post_boost(payload, params = {})
      notify(reporter.to_h) if reporter.to_h.present?
    end

    def handle_post_bookmark(payload, params = {})
      notify(reporter.to_h) if reporter.to_h.present?
    end

    def handle_post_search(payload, params = {})
      notify(reporter.to_h) if reporter.to_h.present?
    end
  end
end
