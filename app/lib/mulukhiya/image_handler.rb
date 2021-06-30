module Mulukhiya
  class ImageHandler < Handler
    def handle_pre_toot(body, params = {})
      self.envelope = body
      return body if parser.command?
      threads = []
      parser.uris.each do |uri|
        next unless updatable?(uri)
        next unless image_uri = create_image_uri(uri)
        thread = Thread.new do
          body[attachment_field] ||= []
          raise 'Too many attachments' if attachment_limit <= body[attachment_field].count
          body[attachment_field].push(sns.upload_remote_resource(image_uri, {response: :id}))
        end
        threads.push(thread)
      end
      threads.each(&:join)
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
