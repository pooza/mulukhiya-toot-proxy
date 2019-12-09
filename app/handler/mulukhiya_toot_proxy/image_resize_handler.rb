module MulukhiyaTootProxy
  class ImageResizeHandler < MediaConvertHandler
    def convert
      return @source.resize(pixel)
    end

    def convertable?
      return false unless @source&.image?
      return false if @source.long_side <= pixel
      @logger.info(class: self.class.to_s, width: @source.width, height: @source.height)
      return true
    end

    def pixel
      return @config['/handler/image_resize/pixel']
    end
  end
end
