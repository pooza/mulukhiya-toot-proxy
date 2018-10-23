require 'mulukhiya/handler'
require 'mulukhiya/error/imprement'

module MulukhiyaTootProxy
  class ImageHandler < Handler
    def exec(body, headers = {})
      body['media_ids'] ||= []
      body['status'].scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        break if body['media_ids'].present?
        next unless updatable?(link)
        body['media_ids'].push(
          @mastodon.upload_remote_resource(create_image_container(link).image_uri),
        )
        increment!
        break
      end
    end

    def updatable?(link)
      raise ImprementError, "#{__method__}が未定義です。"
    end

    def create_image_container(link)
      raise ImprementError, "#{__method__}が未定義です。"
    end
  end
end
