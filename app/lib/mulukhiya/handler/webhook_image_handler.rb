module Mulukhiya
  class WebhookImageHandler < Handler
    def disable?
      return super || sns.account.webhook.nil?
    end

    def handle_pre_webhook(body, params = {})
      body = body.deep_stringify_keys!
      return unless body['attachments'].is_a?(Array)
      return if body[attachment_field].present?
      body['attachments'].each do |attachment|
        uri = Ginseng::URI.parse(attachment['image_url'])
        raise Ginseng::RequestError, "Invalid URL '#{uri}'" unless uri&.absolute?
        body[attachment_field] ||= []
        body[attachment_field].push(sns.upload_remote_resource(uri, {response: :id}))
        result.push(source_url: uri.to_s)
        break
      rescue => e
        errors.push(class: e.class.to_s, message: e.message, attachment: attachment)
      end
      return body
    end
  end
end
