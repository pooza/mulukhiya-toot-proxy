module Mulukhiya
  class ResultNotificationHandler < Handler
    def disable?
      return true unless info_agent_service
      return super
    end

    def disableable?
      return false
    end

    def handle_post_toot(payload, params = {})
      return unless reporter.to_h.present?
      notify(reporter.to_h, {response: reporter.response, spoiler_text:})
    end

    def handle_post_webhook(payload, params = {})
      return unless reporter.to_h.present?
      notify(reporter.to_h, {response: reporter.response, spoiler_text:})
    end

    def handle_post_upload(payload, params = {})
      return unless reporter.to_h.present?
      notify(reporter.to_h, {spoiler_text:})
    end

    def handle_post_fav(payload, params = {})
      return unless reporter.to_h.present?
      notify(reporter.to_h, {spoiler_text:})
    end

    def handle_post_boost(payload, params = {})
      return unless reporter.to_h.present?
      notify(reporter.to_h, {spoiler_text:})
    end

    def handle_post_bookmark(payload, params = {})
      return unless reporter.to_h.present?
      notify(reporter.to_h, {spoiler_text:})
    end

    def spoiler_text
      return handler_config(:spoiler_text)
    end
  end
end
