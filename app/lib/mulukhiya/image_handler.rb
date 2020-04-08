module Mulukhiya
  class ImageHandler < Handler
    def disable?
      return super || Environment.dolphin?
    end

    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      return body if parser.command?
      return body if body[attachment_key].present?
      parser.uris.each do |uri|
        next unless updatable?(uri)
        next unless image = create_image_uri(uri)
        body[attachment_key] ||= []
        body[attachment_key].push(sns.upload_remote_resource(image))
        @result.push(source_url: uri.to_s, image_url: image.to_s)
        break
      rescue Ginseng::GatewayError, RestClient::Exception => e
        errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      end
      return body
    end

    def updatable?(uri)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def create_image_uri(uri)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def verbose?
      return false
    end
  end
end
