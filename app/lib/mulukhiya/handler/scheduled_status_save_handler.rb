module Mulukhiya
  class ScheduledStatusSaveHandler < Handler
    MARGIN = 3600

    def disable?
      return true unless Environment.mastodon_type?
      return super
    end

    def handle_post_toot(payload, params = {})
      response = reporter.response&.parsed_response
      return unless response.is_a?(Hash)
      return unless response['scheduled_at']
      id = response['id']
      return unless id
      scheduled_at = Time.parse(response['scheduled_at'])
      ttl = [(scheduled_at - Time.now).to_i + MARGIN, MARGIN].max
      storage.set(id, {
        account_id: sns.account.id,
        params: payload.to_h,
        scheduled_at: response['scheduled_at'],
      }, ttl:)
    end

    private

    def storage
      @storage ||= ScheduledStatusStorage.new
    end
  end
end
