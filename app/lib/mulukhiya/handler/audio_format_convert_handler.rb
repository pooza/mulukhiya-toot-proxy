module Mulukhiya
  class AudioFormatConvertHandler < MediaConvertHandler
    def convert
      return @source.convert_type(:mp3)
    end

    def convertable?
      return false unless @source&.audio?
      return false if @source.type == 'audio/mpeg'
      @logger.info(handler: underscore_name, type: @source.type)
      return true
    end

    def media_class
      return AudioFile
    end
  end
end
