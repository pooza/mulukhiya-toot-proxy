module Mulukhiya
  class ImageHandler < Handler
    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      return body if parser.command?
      return body if body[attachment_field].present?
      parser.uris.each do |uri|
        next unless updatable?(uri)
        next unless image = create_image_uri(uri)
        body[attachment_field] = [
          sns.upload_remote_resource(image, {response: :id, trim_times: params[:trim_times]}),
        ]
        result.push(source_url: uri.to_s, image_url: image.to_s)
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

    private

    def initialize(params = {})
      super
      @image_uris = {}
    end
  end
end
