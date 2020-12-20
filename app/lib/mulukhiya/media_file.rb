require 'digest/sha1'

module Mulukhiya
  class MediaFile < File
    include Package

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
      return nil
    end

    def height
      return nil
    end

    def duration
      return nil
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

    def self.purge
      bar = ProgressBar.create(total: all.count) if Environment.rake?
      files = []
      all do |path|
        bar&.increment
        next unless File.new(path).mtime < config['/worker/media_cleaning/days'].days.ago
        File.unlink(path)
        files.push(path)
        logger.info(class: 'MediaFile', message: 'delete', path: path)
      rescue => e
        logger.error(error: e, path: path)
      end
      bar&.finish
      puts({'deleted' => files}.to_yaml) if Environment.rake? && files.present?
    end

    def self.all(&block)
      return enum_for(__method__) unless block
      Dir.glob(File.join(Environment.dir, 'tmp/media/*')).sort.each(&block)
    end
  end
end
