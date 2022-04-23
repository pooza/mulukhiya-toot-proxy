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
      return video_stream&.fetch('width')
    end

    def height
      return video_stream&.fetch('height')
    end

    def duration
      return video_stream&.fetch('duration')
    end

    def convert_type(type)
      dest = create_dest_path(f: __method__, type:)
      command = CommandLine.new(['ffmpeg', '-y', '-i', path, dest])
      command.exec unless File.exist?(dest)
      return VideoFile.new(dest)
    end
  end
end
