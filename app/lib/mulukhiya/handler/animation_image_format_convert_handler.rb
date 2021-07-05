module Mulukhiya
  class AnimationImageFormatConvertHandler < MediaConvertHandler
    def convert
      return file.convert_animation_type(type)
    ensure
      result.push(source: {type: file.type})
    end

    def convertable?
      return false unless file
      return false unless file.image?
      return false unless file.animated?
      return false unless type
      return false if file.type == controller_class.default_animation_image_type
      return true
    end
  end
end
