require 'mulukhiya/handler'

module MulukhiyaTootProxy
  class ImageHandler < Handler
    def exec(body, headers = {})
      body['media_ids'] ||= []
      body['status'].scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        break if body['media_ids'].present?
        next unless updatable?(link)
        body['media_ids'].push(
          @mastodon.upload_remote_resource(image_container(link).image_uri),
        )
        increment!
        break
      end
    end

    def updatable?(link)
      raise 'updatable?が未定義です。'
    end

    def image_container(link)
      raise 'image_containerが未定義です。'
    end
  end
end
