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

    def convert_type(type)
      dest = create_dest_path(f: __method__, type:)
      command = CommandLine.new(['ffmpeg', '-y', '-i', path, dest])
      command.exec unless File.exist?(dest)
      return AudioFile.new(dest)
    end
  end
end
