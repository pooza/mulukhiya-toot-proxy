module Mulukhiya
  class VideoFormatConvertHandler < MediaConvertHandler
    def convert
      result.push(source: {type: @source.type})
      return @source.convert_type(@config['/handler/video_format_convert/format'])
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
