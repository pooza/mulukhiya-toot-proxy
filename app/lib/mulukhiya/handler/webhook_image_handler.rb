module Mulukhiya
  class WebhookImageHandler < Handler
    def disable?
      return super || sns.account.webhook.nil?
    end

    def handle_pre_webhook(body, params = {})
      body.deep_stringify_keys!
      threads = []
      (body['attachments'] || []).each do |attachment|
        thread = Thread.new do
          uri = Ginseng::URI.parse(attachment['image_url'])
          raise Ginseng::RequestError, "Invalid URL '#{uri}'" unless uri&.absolute?
          body[attachment_field] ||= []
          body[attachment_field].push(sns.upload_remote_resource(uri, {response: :id}))
          result.push(source_url: uri.to_s)
        end
        threads.push(thread)
      rescue => e
        errors.push(class: e.class.to_s, message: e.message, attachment: attachment)
      end
      threads.each(&:join)
      return body
    end
  end
end
