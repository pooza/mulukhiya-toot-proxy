module Mulukhiya
  class MediaFile < File
    include Package

    def valid?
      return mediatype == default_mediatype
    end

    def mediatype
      return type.split('/').first
    end

    def default_mediatype
      return self.class.to_s.split('::').last.underscore.split('_').first
    end

    def subtype
      return type.split('/').last
    end

    def image?
      return mediatype == 'image'
    end

    def image_file
      return ImageFile.new(path)
    end

    def video?
      return mediatype == 'video'
    end

    def video_file
      return VideoFile.new(path)
    end

    def audio?
      return mediatype == 'audio'
    end

    def audio_file
      return AudioFile.new(path)
    end

    def file
      return image_file if image?
      return video_file if video?
      return audio_file if audio?
      return
    end

    def recommended_name
      @recommended_name ||= File.basename(path, File.extname(path)) + recommended_extname
      return @recommended_name
    end

    def type
      type = Marcel::MimeType.for Pathname.new(path)
      if type.split('/').first == 'application'
        command = CommandLine.new(['file', '-b', '--mime', path])
        command.exec
        type = command.stdout.split(';').first if command.status.zero?
      end
      return type
    rescue => e
      e.log(file: path)
      return MIMEType::DEFAULT
    end

    def extname
      return File.extname(path)
    end

    def recommended_extname
      return MIMEType.extname(type)
    end

    alias valid_extname recommended_extname

    def recommended_extname?
      return true if recommended_extname.nil?
      return extname == recommended_extname
    end

    alias valid_extname? recommended_extname?

    def width
      return nil
    end

    def height
      return nil
    end

    def duration
      return nil
    end

    def aspect
      return width.to_f / height rescue nil
    end

    def long_side
      return [width, height].max rescue nil
    end

    def convert_type(type)
      dest = create_dest_path(f: __method__, type:)
      command = CommandLine.new(['ffmpeg', '-y', '-i', path, dest])
      command.exec unless File.exist?(dest)
      return self.class.new(dest)
    end

    alias convert_format convert_type

    def create_dest_path(params = {})
      params[:extname] ||= MIMEType.extname(params[:type])
      params[:extname] ||= ".#{default_mediatype}"
      params[:content] = File.read(path).adler32
      return File.join(
        Environment.dir,
        'tmp/media',
        "#{params.to_json.adler32}#{params[:extname]}",
      )
    end

    def streams
      unless @streams
        command = CommandLine.new([
          'ffprobe', '-v', 'quiet',
          '-print_format', 'json',
          '-show_streams',
          path
        ])
        command.exec
        @streams = JSON.parse(command.stdout)['streams']
      end
      return @streams
    end

    def video_stream
      return streams.find {|v| v['codec_type'] == 'video'}
    end

    def audio_stream
      return streams.find {|v| v['codec_type'] == 'audio'}
    end

    def self.download(uri)
      path = File.join(
        Environment.dir,
        'tmp/media',
        "#{uri.to_s.adler32}#{File.extname(uri.path)}",
      )
      File.write(path, HTTP.new.get(uri).body)
      return new(path).file
    end

    def self.purge
      worker = Worker.create(:media_cleaning)
      all.select {|f| File.new(f).mtime < worker.worker_config(:hours).hours.ago}.each do |path|
        FileUtils.rm_rf(path)
        logger.info(class: to_s, method: __method__, path:)
      rescue => e
        e.log(path:)
      end
    end

    def self.all(&block)
      return enum_for(__method__) unless block
      finder = Ginseng::FileFinder.new
      finder.dir = File.join(Environment.dir, 'tmp/media')
      finder.patterns.push('*')
      finder.exec.select {|f| FileTest.file?(f)}.each(&block)
    end
  end
end
