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

    def pixel
      return config['/handler/image_resize/pixel']
    end
  end
end
