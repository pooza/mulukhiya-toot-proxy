module Mulukhiya
  class VideoFormatConvertHandler < MediaConvertHandler
    def convert
      return @source.convert_type(controller_class.default_video_type)
    ensure
      result.push(source: {type: @source.type})
    end

    def convertable?
      return false unless @source&.video?
      return false if @source.type == controller_class.default_video_type
      return true
    end

    def media_class
      return VideoFile
    end
  end
end
