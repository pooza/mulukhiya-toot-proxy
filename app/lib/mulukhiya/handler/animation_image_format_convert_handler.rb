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
      return false if file.type == type
      return true
    end

    def schema
      return super.deep_merge(
        type: 'object',
        properties: {webp: {type: 'boolean'}},
      )
    end

    def type
      return controller_class.default_animation_image_type
    end
  end
end
