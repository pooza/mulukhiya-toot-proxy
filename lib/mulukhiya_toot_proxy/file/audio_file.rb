module MulukhiyaTootProxy
  class AudioFile < MediaFile
    alias audio? valid?

    def type
      return false unless File.readable?(path)
      detail_type['streams'].each do |stream|
        return stream['codec_name'] if stream['codec_type'] == 'audio'
      end
    rescue
      return nil
    end

    def convert_type(type)
      dest = File.join(Environment.dir, 'tmp/media', "#{digest(f: __method__)}.#{type}")
      system('ffmpeg', path, dest, {exception: true}) unless File.exist?(dest)
      return ImageFile.new(dest)
    end

    def detail_info
      @detail_info ||= JSON.parse(
        `ffprobe -v quiet -print_format json -show_streams #{path.shellescape}`,
      )
      return @detail_info
    rescue => e
      @logger.error(e)
      return nil
    end
  end
end
