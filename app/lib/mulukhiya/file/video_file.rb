module Mulukhiya
  class VideoFile < MediaFile
    def values
      return {
        type:,
        mediatype:,
        subtype:,
        duration:,
        width:,
        height:,
        size:,
        length: size,
      }
    end

    alias to_h values

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
      dest = create_dest_path(f: __method__, type:)
      command = CommandLine.new(['ffmpeg', '-y', '-i', path, dest])
      command.exec unless File.exist?(dest)
      return VideoFile.new(dest)
    end
  end
end
