module Mulukhiya
  class VideoFile < MediaFile
    # ハンドラの外（rake・CLI・テスト）で ffmpeg を回すときの上限 (秒)。
    # ⚠ ハンドラの中では `Event::HANDLER_DEADLINE_KEY` の残りのほうが短くなる。
    DEFAULT_FFMPEG_TIMEOUT = 90

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

    # ffmpeg 1 回あたりの締切 (秒)。
    #
    # ⚠⚠ **ハンドラ締切と同じキーを読んではいけない (#4696)。**以前は内外とも
    # `/handler/video_format_convert/timeout` = 90 で、**外側の
    # `Event#run_handler` の `thread.join` が先に始まり、さらに transcode の前に
    # `video_stream` のプローブ（`/ffmpeg/probe/timeout` = 30）が挟まる**ため、
    # 内側の `Timeout.timeout(90)` は**構造的に一度も発火しなかった**。
    #
    # ⚠ 発火しないと `log_ffmpeg_error` と `raise "ffmpeg failed: ..."` の経路ごと
    # 死に、残るのは `{message: 'timeout'}` 1 行だけになる。さらに `Thread#kill` は
    # ffmpeg にシグナルを送らないので、変換途中の `tmp/media/*.mp4` が残る。
    #
    # **ハンドラの締切から残りを逆算する**ので、内側が必ず先に切れ、かつ使える時間は
    # 縮まない。⚠ ハンドラの外（rake・テスト・CLI）では締切が無いので、
    # `/ffmpeg/timeout` の上限だけが効く。
    def ffmpeg_timeout
      return [handler_deadline_remaining, ffmpeg_timeout_limit].compact.min
    end

    # ハンドラ締切までの残り。⚠ **0 以下を渡さない** — `Timeout.timeout(0)` は
    # 「制限なし」の意味になり、**塞いだはずの穴がそのまま開く**。
    def handler_deadline_remaining
      return nil unless deadline = Thread.current[Event::HANDLER_DEADLINE_KEY]
      return [deadline - Time.now, 1].max
    end

    def ffmpeg_timeout_limit
      return Config.instance['/ffmpeg/timeout']
    rescue Ginseng::ConfigError
      # 既定値は config/application.yaml にある。設定ファイルが古い環境でも
      # 「制限なし」へ退行させないための定数フォールバック。
      return DEFAULT_FFMPEG_TIMEOUT
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
