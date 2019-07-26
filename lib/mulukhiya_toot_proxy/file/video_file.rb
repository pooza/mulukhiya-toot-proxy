module MulukhiyaTootProxy
  class VideoFile < MediaFile
    alias video? valid?

    def convert_type(type)
      dest = File.join(Environment.dir, 'tmp/media', "#{digest(f: __method__)}.#{type}")
      system('ffmpeg', '-y', '-i', path, dest, {exception: true}) unless File.exist?(dest)
      return VideoFile.new(dest)
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
