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

    def convert_type(type)
      dest = create_dest_path(f: __method__, type:)
      command = FFmpegCommandBuilder.remux_video(path, dest, audio: audio?)
      command.exec(timeout: ffmpeg_timeout)
      unless command.status.zero?
        log_ffmpeg_error(command, 'remux')
        command = FFmpegCommandBuilder.transcode_video(path, dest, audio: audio?)
        command.exec(timeout: ffmpeg_timeout)
      end
      raise "ffmpeg failed: #{command.stderr}" unless command.status.zero?
      return self.class.new(dest)
    end

    def transcode(type)
      dest = create_dest_path(f: __method__, type:)
      command = FFmpegCommandBuilder.transcode_video(path, dest, audio: audio?)
      command.exec(timeout: ffmpeg_timeout)
      raise "ffmpeg failed: #{command.stderr}" unless command.status.zero?
      return self.class.new(dest)
    end

    def audio?
      return audio_stream.present?
    rescue
      return false
    end

    def video_codec
      return video_stream.fetch('codec_name')
    rescue => e
      e.log(file: path)
      return nil
    end

    def pix_fmt
      return video_stream.fetch('pix_fmt')
    rescue => e
      e.log(file: path)
      return nil
    end

    def width
      return video_stream.fetch('width').to_i
    rescue => e
      e.log(file: path)
      return nil
    end

    def height
      return video_stream.fetch('height').to_i
    rescue => e
      e.log(file: path)
      return nil
    end

    def duration
      duration = video_stream.fetch('duration', nil)
      duration ||= video_stream.dig('tags', 'DURATION')
      return duration.to_f
    rescue => e
      e.log(file: path)
      return nil
    end

    private

    def ffmpeg_timeout
      return Config.instance['/handler/video_format_convert/timeout']
    rescue
      return 90
    end

    def log_ffmpeg_error(command, phase)
      logger.error(
        class: self.class.to_s,
        phase:,
        status: command.status,
        stderr: command.stderr&.then {|s| s.lines.last(5).join},
        file: path,
      )
    end
  end
end
