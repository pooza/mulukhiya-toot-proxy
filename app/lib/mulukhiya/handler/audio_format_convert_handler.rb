module Mulukhiya
  class AudioFormatConvertHandler < MediaConvertHandler
    def convert
      result.push(source: {type: @source.type})
      return @source.convert_type(:mp3)
    end

    def convertable?
      return false unless @source&.audio?
      return false if @source.type == 'audio/mpeg'
      return true
    end

    def media_class
      return AudioFile
    end
  end
end
