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

    def convert_type(type)
      dest = create_dest_path(f: __method__, type:)
      command = FFmpegCommandBuilder.remux_audio(path, dest)
      command.exec
      unless command.status.zero?
        command = FFmpegCommandBuilder.transcode_audio(path, dest)
        command.exec
      end
      return self.class.new(dest)
    end

    def duration
      return audio_stream.fetch('duration').to_f
    rescue => e
      e.log(file: path)
      return nil
    end
  end
end
