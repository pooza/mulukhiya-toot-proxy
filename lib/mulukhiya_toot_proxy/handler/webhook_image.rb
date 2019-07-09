module MulukhiyaTootProxy
  class WebhookImageHandler < Handler
    def handle_pre_webhook(body, params = {})
      return unless body['attachments'].is_a?(Array)
      body['media_ids'] ||= []
      return if body['media_ids'].present?
      body['attachments'].each do |attachment|
        uri = Ginseng::URI.parse(attachment['image_url'])
        next unless uri&.absolute?
        body['media_ids'].push(@mastodon.upload_remote_resource(uri))
        @result.push(uri.to_s)
        break
      rescue => e
        @logger.error(Ginseng::Error.create(e).to_h.concat(attachment: attachment))
        next
      end
    end
  end
end
