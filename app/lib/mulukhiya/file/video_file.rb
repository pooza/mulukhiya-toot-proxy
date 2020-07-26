module Mulukhiya
  class VideoFile < MediaFile
    alias video? valid?

    def width
      detail_info['streams'].each do |stream|
        next unless stream['codec_type'] == default_mediatype
        next if stream['width'].empty?
        return stream['width'].to_i
      end
      return nil
    end

    def height
      detail_info['streams'].each do |stream|
        next unless stream['codec_type'] == default_mediatype
        next if stream['height'].empty?
        return stream['height'].to_i
      end
      return nil
    end

    def duration
      detail_info['streams'].each do |stream|
        next unless stream['codec_type'] == default_mediatype
        next if stream['duration'].empty?
        return stream['duration'].to_f
      end
      return nil
    end

    def convert_format(type)
      dest = create_dest_path(f: __method__, type: type)
      command = CommandLine.new(['ffmpeg', '-y', '-i', path, dest])
      command.exec unless File.exist?(dest)
      return VideoFile.new(dest)
    end

    def detail_info
      unless @detail_info
        command = CommandLine.new([
          'ffprobe', '-v', 'quiet',
          '-print_format', 'json',
          '-show_streams',
          path
        ])
        command.exec
        @detail_info = JSON.parse(command.stdout)
      end
      return @detail_info
    end
  end
end
