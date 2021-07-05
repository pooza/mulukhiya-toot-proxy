module Mulukhiya
  class VideoFormatConvertHandler < MediaConvertHandler
    def convert
      return file.convert_type(type)
    ensure
      result.push(source: {type: file.type})
    end

    def convertable?
      return false unless file
      return false unless file.video?
      return false if file.type == controller_class.default_video_type
      return true
    end

    def media_class
      return VideoFile
    end
  end
end
