module Mulukhiya
  class WebhookImageHandler < Handler
    def disable?
      return super || sns.account.webhook.nil?
    end

    def handle_pre_webhook(body, params = {})
      return unless body['attachments'].is_a?(Array)
      return if body[attachment_key].present?
      body['attachments'].each do |attachment|
        uri = Ginseng::URI.parse(attachment['image_url'])
        raise Ginseng::RequestError "Invalid URL '#{uri}'" unless uri&.absolute?
        body[attachment_key] ||= []
        body[attachment_key].push(sns.upload_remote_resource(uri, {response: :id}))
        result.push(source_url: uri.to_s)
        break
      rescue => e
        errors.push(class: e.class.to_s, message: e.message, attachment: attachment)
      end
    end
  end
end
