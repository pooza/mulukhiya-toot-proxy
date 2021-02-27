module Mulukhiya
  class AudioFormatConvertHandler < MediaConvertHandler
    def convert
      return @source.convert_type(type)
    ensure
      result.push(source: {type: @source.type})
    end

    def convertable?
      return false unless @source&.audio?
      return false if @source.type == type
      return true
    end

    def type
      return controller_class.default_audio_type
    end

    def media_class
      return AudioFile
    end
  end
end
