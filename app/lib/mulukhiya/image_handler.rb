module Mulukhiya
  class ImageHandler < Handler
    def disable?
      return !Environment.mastodon? || super
    end

    def handle_pre_toot(body, params = {})
      @status = body[status_field].to_s
      return body if parser.command?
      body['media_ids'] ||= []
      return body if body['media_ids'].present?
      parser.uris.each do |uri|
        link = uri.to_s
        next unless updatable?(link)
        image = create_image_uri(link)
        body['media_ids'].push(sns.upload_remote_resource(image))
        @result.push(source_url: link, image_url: image.to_s)
        break
      rescue Ginseng::GatewayError, RestClient::Exception => e
        @logger.error(e)
      end
      return body
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
