module Mulukhiya
  class AudioFormatConvertHandler < MediaConvertHandler
    def convert
      return file.convert_type(type)
    ensure
      result.push(source: {type: file.type})
    end

    def convertable?
      return false unless file
      return false unless file.audio?
      return false if file.type == type
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
