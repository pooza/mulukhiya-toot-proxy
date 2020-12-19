module Mulukhiya
  class AudioFile < MediaFile
    def values
      return {
        type: type,
        mediatype: mediatype,
        subtype: subtype,
        duration: duration,
        size: size,
      }
    end

    alias to_h values

    def type
      return [mediatype, subtype].join('/') if invalid_mediatype?
      return super
    end

    def mediatype
      return default_mediatype if invalid_mediatype?
      return super
    end

    def subtype
      return "x-#{audio_stream['codec_name'].downcase}" if invalid_mediatype?
      return super
    end

    def duration
      return audio_stream['duration'].to_f if audio_stream&.dig('duration')
      return nil
    end

    def convert_type(type)
      dest = create_dest_path(f: __method__, type: type)
      command = CommandLine.new(['ffmpeg', '-y', '-i', path, dest])
      command.exec unless File.exist?(dest)
      return AudioFile.new(dest)
    end

    def invalid_mediatype?
      return mimemagic&.mediatype == 'application' && audio_stream.present?
    end
  end
end
