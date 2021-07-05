module Mulukhiya
  class MediaConvertHandler < Handler
    attr_reader :image_field, :file

    def handle_pre_upload(payload, params = {})
      @file = media_class.new(payload[image_field][:tempfile].path)
      return unless convertable?
      return unless @dest = convert
      payload[image_field][:org_tempfile] ||= payload[image_field][:tempfile]
      payload[image_field][:tempfile] = @dest
    rescue => e
      logger.error(error: e)
      errors.push(class: e.class.to_s, message: e.message, file: @source.path)
    end

    def handle_pre_thumbnail(payload, params = {})
      @image_field = :thumbnail
      handle_pre_upload(payload, params)
    end

    def handle_post_thumbnail(payload, params = {})
      @image_field = :thumbnail
      handle_post_upload(payload, params)
    end

    def convert
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def convertable?
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def type
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def media_class
      return ImageFile
    end

    private

    def initialize(params = {})
      super
      @image_field = :file
    end
  end
end
