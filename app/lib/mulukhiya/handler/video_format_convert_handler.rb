module Mulukhiya
  class VideoFormatConvertHandler < MediaConvertHandler
    def convert
      return @source.convert_type(:mp4)
    end

    def convertable?
      return false unless @source&.video?
      return false if @source.type == 'video/mp4'
      return true
    end

    def media_class
      return VideoFile
    end
  end
end
