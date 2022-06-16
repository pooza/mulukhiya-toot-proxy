module Mulukhiya
  class AudioFile < MediaFile
    def values
      return {
        type:,
        mediatype:,
        subtype:,
        duration:,
        size:,
        length: size,
      }
    end

    alias to_h values

    def duration
      return audio_stream.fetch('duration').to_f
    rescue => e
      e.log(file: path)
      return nil
    end
  end
end
