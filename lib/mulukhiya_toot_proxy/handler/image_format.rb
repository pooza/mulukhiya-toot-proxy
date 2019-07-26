module MulukhiyaTootProxy
  class ImageFormatHandler < MediaConvertHandler
    def convert
      return @source&.convert_type(:jpeg)
    end

    def convertable?
      return false unless @source&.image?
      return false if @source.type == 'image/jpeg'
      return false if @source.type == 'image/gif'
      return false if @source.alpha?
      return true
    end
  end
end
