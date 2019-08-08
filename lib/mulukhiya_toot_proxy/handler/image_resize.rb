module MulukhiyaTootProxy
  class ImageResizeHandler < MediaConvertHandler
    def convert
      return @source&.resize(@config['/handler/image_resize/pixel'])
    end

    def convertable?
      return false unless @source&.image?
      return @config['/handler/image_resize/pixel'] < @source.long_side
    end
  end
end
