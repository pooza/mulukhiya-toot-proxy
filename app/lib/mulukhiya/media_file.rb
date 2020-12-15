require 'digest/sha1'

module Mulukhiya
  class MediaFile < File
    def initialize(path, mode = 'r', perm = 0o600)
      @logger = Logger.new
      super
    end

    def valid?
      return mediatype == default_mediatype
    end

    def mediatype
      return mimemagic&.mediatype
    end

    def default_mediatype
      return self.class.to_s.split('::').last.underscore.split('_').first
    end

    def subtype
      return mimemagic&.subtype
    end

    def type
      return mimemagic.to_s
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

    alias valid_exename? recommended_extname?

    def width
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def height
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def duration
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def aspect
      return width.to_f / height
    rescue
      return nil
    end

    def long_side
      return [width, height].max
    rescue
      return nil
    end

    def convert_type(type)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    alias convert_format convert_type

    def create_dest_path(params = {})
      params[:extname] ||= MIMEType.extname(params[:type])
      params[:extname] ||= ".#{default_mediatype}"
      params[:content] = Digest::SHA1.hexdigest(File.read(path))
      return File.join(
        Environment.dir,
        'tmp/media',
        "#{Digest::SHA1.hexdigest(params.to_json)}#{params[:extname]}",
      )
    end

    def mimemagic
      @mimemagic ||= MimeMagic.by_magic(self)
      return @mimemagic
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

    def self.purge(params = {})
      logger = Logger.new
      config = Config.instance
      files = []
      all do |path|
        next unless File.new(path).mtime < config['/worker/media_cleaning/days'].days.ago
        File.unlink(path)
        files.push(path)
        logger.info(class: 'MediaFile', message: 'delete', path: path)
      rescue => e
        logger.error(error: e, path: path)
      end
      puts({'deleted' => files}.to_yaml) if Environment.rake? && files.present?
    end

    def self.all
      return enum_for(__method__) unless block_given?
      paths = Dir.glob(File.join(Environment.dir, 'tmp/media/*'))
      bar = ProgressBar.create(total: paths.count) if Environment.rake?
      paths.each do |path|
        bar.increment if Environment.rake?
        yield path
      end
      bar.finish if Environment.rake?
    end
  end
end
