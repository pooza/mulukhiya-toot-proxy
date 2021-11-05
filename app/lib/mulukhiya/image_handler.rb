module Mulukhiya
  class ImageHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      return if parser.command?
      payload[attachment_field] ||= []
      parser.uris.select {|v| updatable?(v)}.first(attachment_limit).each do |uri|
        Thread.new do
          payload[attachment_field].push(sns.upload_remote_resource(create_image_uri(uri), {
            response: :id,
            trim_times: trim_times,
          }))
        rescue => e
          errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
        end
      end.each(&:join)
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
