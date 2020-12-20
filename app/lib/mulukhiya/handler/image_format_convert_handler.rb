module Mulukhiya
  class ImageFormatConvertHandler < MediaConvertHandler
    def convert
      return @source.convert_type(type)
    ensure
      result.push(source: {type: @source.type})
    end

    def convertable?
      return false unless @source&.image?
      return false if @source.type == type
      return false if @source.type == 'image/gif'
      return false if @source.alpha?
      return false if @source.animated?
      return true
    end

    def type
      return config['/handler/image_format_convert/type']
    end
  end
end
