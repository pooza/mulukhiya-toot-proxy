module Mulukhiya
  class AudioFile < MediaFile
    alias audio? valid?

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

    def width
      return nil
    end

    def height
      return nil
    end

    def duration
      return audio_stream['duration'].to_f if audio_stream&.dig('duration')
      return nil
    end

    def convert_format(type)
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
