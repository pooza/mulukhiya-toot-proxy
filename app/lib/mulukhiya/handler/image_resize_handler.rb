module Mulukhiya
  class ImageResizeHandler < MediaConvertHandler
    def convert
      result.push(source: {width: @source.width, height: @source.height})
      return @source.resize(pixel)
    end

    def convertable?
      return false unless @source&.image?
      return false if @source.long_side <= pixel
      return true
    end

    def pixel
      return @config['/handler/image_resize/pixel']
    end
  end
end
