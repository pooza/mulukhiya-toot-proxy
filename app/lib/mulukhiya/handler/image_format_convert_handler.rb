module Mulukhiya
  class ImageFormatConvertHandler < MediaConvertHandler
    def convert
      return @source.convert_type(controller_class.default_image_type)
    ensure
      result.push(source: {type: @source.type})
    end

    def convertable?
      return false unless @source&.image?
      return false if @source.type == controller_class.default_image_type
      return false if @source.type == 'image/gif'
      return false if @source.alpha?
      return false if @source.animated?
      return true
    end
  end
end
