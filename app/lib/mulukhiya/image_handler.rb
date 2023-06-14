module Mulukhiya
  class ImageHandler < Handler
    def handle_pre_toot(payload, params = {})
      payload[attachment_field] ||= []
      self.payload = payload
      return if parser.command?
      parser.uris.select {|v| updatable?(v)}.each do |uri|
        next if sns.max_media_attachments <= payload[attachment_field].count
        payload[attachment_field].push(upload(uri))
      rescue => e
        errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      end
      return payload
    end

    def upload(uri, params = {})
      uri = create_image_uri(uri) rescue uri
      params[:trim_times] ||= trim_times
      return super
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
