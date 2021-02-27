module Mulukhiya
  class AudioFormatConvertHandler < MediaConvertHandler
    def convert
      return @source.convert_type(controller_class.default_audio_type)
    ensure
      result.push(source: {type: @source.type})
    end

    def convertable?
      return false unless @source&.audio?
      return false if @source.type == controller_class.default_audio_type
      return true
    end

    def media_class
      return AudioFile
    end
  end
end
