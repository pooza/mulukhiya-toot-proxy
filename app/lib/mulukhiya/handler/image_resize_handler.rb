module Mulukhiya
  class ImageResizeHandler < MediaConvertHandler
    def convert
      return file.resize(pixel)
    ensure
      result.push(source: {width: file.width, height: file.height})
    end

    def convertable?
      return false unless file
      return false unless file.image?
      return false if file.long_side <= pixel
      return true
    end

    def schema
      return super.deep_merge(
        type: 'object',
        properties: {
          pixel: {type: 'integer'},
        },
        required: ['pixel'],
      )
    end

    def pixel
      return config['/handler/image_resize/pixel']
    end
  end
end
