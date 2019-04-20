module MulukhiyaTootProxy
  class ImageHandler < Handler
    def exec(body, headers = {})
      body['media_ids'] ||= []
      body['status'].scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        break if body['media_ids'].present?
        next unless updatable?(link)
        image = create_image_uri(link)
        body['media_ids'].push(@mastodon.upload_remote_resource(image))
        @result.push(image.to_s)
        break
      rescue Ginseng::GatewayError => e
        @logger.error(e)
        next
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
