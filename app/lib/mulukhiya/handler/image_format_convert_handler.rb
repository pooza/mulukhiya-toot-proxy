module Mulukhiya
  class ImageFormatConvertHandler < MediaConvertHandler
    def convert
      return file.convert_type(type)
    ensure
      result.push(source: {type: file.type})
    end

    def convertable?
      return false unless file
      return false unless file.image?
      return false if file.type == type
      return false if file.gif?
      return false if file.animated?
      return true
    end

    def type
      return controller_class.default_image_type
    end
  end
end
