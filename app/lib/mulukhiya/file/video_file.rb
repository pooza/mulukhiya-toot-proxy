module Mulukhiya
  class VideoFile < MediaFile
    def values
      return {
        type: type,
        mediatype: mediatype,
        subtype: subtype,
        duration: duration,
        width: width,
        height: height,
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
      return "x-#{video_stream['codec_name'].downcase}" if invalid_mediatype?
      return super
    end

    def width
      return video_stream['width'].to_i if video_stream&.dig('width')
      return nil
    end

    def height
      return video_stream['height'].to_i if video_stream&.dig('height')
      return nil
    end

    def duration
      return video_stream['duration'].to_f if video_stream&.dig('duration')
      return nil
    end

    def convert_type(type)
      dest = create_dest_path(f: __method__, type: type)
      command = CommandLine.new(['ffmpeg', '-y', '-i', path, dest])
      command.exec unless File.exist?(dest)
      return VideoFile.new(dest)
    end

    def invalid_mediatype?
      return mimemagic&.mediatype == 'application' && video_stream.present?
    end
  end
end
