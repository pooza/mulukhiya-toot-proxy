module Mulukhiya
  class MediaConvertHandler < Handler
    def handle_pre_upload(payload, params = {})
      return unless @source = source_file(payload)
      return unless convertable?
      return unless @dest = convert
      payload[:file][:org_tempfile] ||= payload[:file][:tempfile]
      payload[:file][:tempfile] = @dest
    rescue => e
      logger.error(error: e)
      errors.push(class: e.class.to_s, message: e.message, file: payload[:file][:tempfile].path)
    end

    def handle_pre_thumbnail(payload, params = {})
      return unless @source = source_file(payload, :thumbnail)
      return unless convertable?
      return unless @dest = convert
      payload[:thumbnail][:org_tempfile] ||= payload[:thumbnail][:tempfile]
      payload[:thumbnail][:tempfile] = @dest
    rescue => e
      logger.error(error: e)
      errors.push(class: e.class.to_s, message: e.message, file: payload[:file][:tempfile].path)
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

    def source_file(payload, key = :file)
      return media_class.new(payload[key][:tempfile].path) rescue nil
    end
  end
end
