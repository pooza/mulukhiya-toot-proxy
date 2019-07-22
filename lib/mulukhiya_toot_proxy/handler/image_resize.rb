module MulukhiyaTootProxy
  class ImageResizeHandler < MediaConvertHandler
    def convert
      return @file&.resize(@config['/handler/image_resize/pixel'])
    end

    def convertable?
      return false unless @file&.image?
      return @config['/handler/image_resize/pixel'] < @file.long_side
    end
  end
end
