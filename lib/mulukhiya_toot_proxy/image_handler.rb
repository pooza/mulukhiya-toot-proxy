module MulukhiyaTootProxy
  class ImageHandler < Handler
    def exec(body, headers = {})
      body['media_ids'] ||= []
      body['status'].scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        break if body['media_ids'].present?
        next unless updatable?(link)
        body['media_ids'].push(
          @mastodon.upload_remote_resource(create_image_uri(link)),
        )
        increment!
        break
      end
    rescue Ginseng::GatewayError => ex
      @logger.error(ex.to_h)
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
