module Mulukhiya
  class ImageResizeHandler < MediaConvertHandler
    def convert
      return @source.resize(pixel)
    ensure
      result.push(source: {width: @source.width, height: @source.height})
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
