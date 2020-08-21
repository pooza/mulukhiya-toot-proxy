module Mulukhiya
  class VideoFormatConvertHandler < MediaConvertHandler
    def convert
      return @source.convert_format(extname)
    ensure
      result.push(source: {type: @source.type})
    end

    def convertable?
      return false unless @source&.video?
      return false if @source.type == type
      return true
    end

    def type
      return @config['/handler/video_format_convert/type']
    end

    def media_class
      return VideoFile
    end
  end
end
