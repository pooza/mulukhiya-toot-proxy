module Mulukhiya
  class WebhookImageHandler < Handler
    def disable?
      return true unless sns.account.webhook
      return super
    end

    def handle_pre_webhook(payload, params = {})
      payload.deep_stringify_keys!
      (payload['attachments'] || []).map do |attachment|
        Thread.new do
          uri = Ginseng::URI.parse(attachment['image_url'])
          raise Ginseng::RequestError, "Invalid URL '#{uri}'" unless uri&.absolute?
          payload[attachment_field] ||= []
          payload[attachment_field].push(sns.upload_remote_resource(uri, {response: :id}))
          result.push(source_url: uri.to_s)
        rescue => e
          errors.push(class: e.class.to_s, message: e.message, attachment: attachment)
        end
      end.each(&:join)
    end
  end
end
