module MulukhiyaTootProxy
  class ImageHandler < Handler
    def disable?
      return super || Environment.sns_class.is_a?(DolphinService)
    end

    def handle_pre_toot(body, params = {})
      body['media_ids'] ||= []
      return if body['media_ids'].present?
      body[message_field].scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        next unless updatable?(link)
        image = create_image_uri(link)
        body['media_ids'].push(sns.upload_remote_resource(image))
        @result.push(url: image.to_s)
        break
      rescue Ginseng::GatewayError, RestClient::Exception => e
        @logger.error(e)
      end
    end

    def updatable?(link)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    alias executable? updatable?

    def create_image_uri(link)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
