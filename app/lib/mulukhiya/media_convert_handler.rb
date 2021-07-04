module Mulukhiya
  class MediaConvertHandler < Handler
    def handle_pre_upload(payload, params = {})
      @source ||= media_class.new(payload[:file][:tempfile].path)
      return unless convertable?
      return unless @dest = convert
      payload[:file][:org_tempfile] ||= payload[:file][:tempfile]
      payload[:file][:tempfile] = @dest
    rescue => e
      logger.error(error: e)
      errors.push(class: e.class.to_s, message: e.message, file: @source.path)
    end

    def handle_pre_thumbnail(payload, params = {})
      return unless @source = media_class.new(payload[:thumbnail][:tempfile].path)
      return handle_pre_upload(payload, params)
    rescue => e
      logger.error(error: e)
      errors.push(class: e.class.to_s, message: e.message, file: @source.path)
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
  end
end
