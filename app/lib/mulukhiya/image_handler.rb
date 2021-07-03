module Mulukhiya
  class ImageHandler < Handler
    def handle_pre_toot(body, params = {})
      self.payload = body
      return body if parser.command?
      threads = []
      parser.uris.each do |uri|
        next unless updatable?(uri)
        next unless image_uri = create_image_uri(uri)
        body[attachment_field] ||= []
        next unless body[attachment_field].count < attachment_limit
        thread = Thread.new do
          body[attachment_field].push(
            sns.upload_remote_resource(image_uri, {response: :id, trim_times: trim_times}),
          )
        end
        threads.push(thread)
      end
      threads.each(&:join)
      return body
    end

    def trim_times
      return 0
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
