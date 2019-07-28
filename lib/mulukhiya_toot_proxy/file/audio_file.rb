module MulukhiyaTootProxy
  class AudioFile < MediaFile
    alias audio? valid?

    def width
      return nil
    end

    def height
      return nil
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
      system('ffmpeg', '-y', '-i', path, dest, {exception: true}) unless File.exist?(dest)
      return AudioFile.new(dest)
    end

    def detail_info
      @detail_info ||= JSON.parse(
        `ffprobe -v quiet -print_format json -show_streams #{path.shellescape}`,
      )
      return @detail_info
    end
  end
end
