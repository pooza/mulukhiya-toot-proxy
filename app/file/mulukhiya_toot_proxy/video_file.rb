module MulukhiyaTootProxy
  class VideoFile < MediaFile
    alias video? valid?

    def width
      detail_info['streams'].each do |stream|
        next unless stream['codec_type'] == default_mediatype
        next unless stream['width'].present?
        return stream['width'].to_i
      end
    end

    def height
      detail_info['streams'].each do |stream|
        next unless stream['codec_type'] == default_mediatype
        next unless stream['height'].present?
        return stream['height'].to_i
      end
    end

    def duration
      detail_info['streams'].each do |stream|
        next unless stream['codec_type'] == default_mediatype
        next unless stream['duration'].present?
        return stream['duration'].to_f
      end
    end

    def convert_type(type)
      dest = create_dest_path(f: __method__, type: type)
      command = CommandLine.new(['ffmpeg', '-y', '-i', path, dest])
      command.exec unless File.exist?(dest)
      return VideoFile.new(dest)
    end

    def detail_info
      unless @detail_info
        command = CommandLine.new
        command.args = ['ffprobe', '-v', 'quiet', '-print_format', 'json', '-show_streams', path]
        command.exec
        @detail_info = JSON.parse(command.stdout)
      end
      return @detail_info
    end
  end
end
