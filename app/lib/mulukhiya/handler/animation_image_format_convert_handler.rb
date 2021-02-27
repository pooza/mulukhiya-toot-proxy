module Mulukhiya
  class AnimationImageFormatConvertHandler < MediaConvertHandler
    def convert
      return @source.convert_animation_type(type)
    ensure
      result.push(source: {type: @source.type})
    end

    def convertable?
      return false unless @source&.image?
      return false unless @source.animated?
      return false if @source.type == type
      return true
    end

    def type
      return controller_class.default_animation_image_type
    end
  end
end
