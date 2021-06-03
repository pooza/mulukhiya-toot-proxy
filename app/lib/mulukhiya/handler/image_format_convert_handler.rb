module Mulukhiya
  class ImageFormatConvertHandler < MediaConvertHandler
    def convert
      return @source.convert_type(type)
    ensure
      result.push(source: {type: @source.type})
    end

    def convertable?
      return false unless @source&.image?
      return false unless type
      return false if @source.type == type
      return false if @source.type == 'image/gif'
      return false if detect_alpha? && @source.alpha?
      return false if @source.animated?
      return true
    end

    def detect_alpha?
      return config['/handler/image_format_convert/alpha'] == true
    end

    def type
      return controller_class.default_image_type
    end
  end
end
