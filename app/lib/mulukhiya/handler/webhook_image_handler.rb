module Mulukhiya
  class WebhookImageHandler < Handler
    def disable?
      return true unless controller_class.webhook?
      return true unless sns.account&.webhook
      return super
    end

    def handle_pre_webhook(payload, params = {})
      payload.deep_stringify_keys!
      payload[attachment_field] = Concurrent::Array.new(payload[attachment_field] || [])
      in_threads = Parallel.processor_count
      Parallel.each((payload['attachments'] || []), in_threads:) do |attachment|
        next unless uri = Ginseng::URI.parse(attachment['image_url'])
        next if sns.max_media_attachments <= payload[attachment_field].count
        payload[attachment_field].push(upload(uri))
        result.push(source_url: uri.to_s)
      rescue => e
        errors.push(class: e.class.to_s, message: e.message, attachment:)
      end
    end
  end
end
