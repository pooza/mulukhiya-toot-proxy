module Mulukhiya
  class WebhookImageHandler < Handler
    def disable?
      return true unless sns.account.webhook
      return super
    end

    def handle_pre_webhook(payload, params = {})
      payload.deep_stringify_keys!
      payload[attachment_field] ||= []
      (payload['attachments'] || []).map do |attachment|
        Thread.new do
          next unless uri = Ginseng::URI.parse(attachment['image_url'])
          next if attachment_limit <= payload[attachment_field].count
          payload[attachment_field].push(upload(uri))
          result.push(source_url: uri.to_s)
        rescue => e
          errors.push(class: e.class.to_s, message: e.message, attachment:)
        end
      end.each(&:join)
    end
  end
end
