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
    end

    def updatable?(link)
      raise ImprementError, "#{__method__}が未実装です。"
    end

    def create_image_uri(link)
      raise ImprementError, "#{__method__}が未実装です。"
    end
  end
end
