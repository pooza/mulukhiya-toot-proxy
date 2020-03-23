module Mulukhiya
  class ImageHandler < Handler
    def disable?
      return !Environment.mastodon? || super
    end

    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      return body if parser.command?
      body['media_ids'] ||= []
      return body if body['media_ids'].present?
      parser.uris.each do |uri|
        next unless updatable?(uri)
        image = create_image_uri(uri)
        body['media_ids'].push(sns.upload_remote_resource(image))
        @result.push(source_url: uri.to_s, image_url: image.to_s)
        break
      rescue Ginseng::GatewayError, RestClient::Exception => e
        @logger.error(Ginseng::Error.create(e).to_h.merge(url: uri.to_s))
      end
      return body
    end

    def updatable?(uri)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def create_image_uri(uri)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
