module Mulukhiya
  class VideoFile < MediaFile
    # ffmpeg 1 回あたりの上限 (秒)。`/ffmpeg/timeout` が読めないときの既定。
    # ⚠ ハンドラの中では `Event::HANDLER_DEADLINE_KEY` の残りと**短いほう**が効く。
    DEFAULT_FFMPEG_TIMEOUT = 90

    # 内側へ渡す下限 (秒)。⚠ **0 以下を渡さない** — `Timeout.timeout(0)` は
    # 「制限なし」の意味になり、塞いだはずの穴がそのまま開く。
    # ⚠ 1 秒ではなくこの値なのは、`timeout` に数秒を設定したハンドラで
    # **下限が締切そのものを追い越さない**ようにするため（PR #4706 の Codex P2）。
    MIN_FFMPEG_TIMEOUT = 0.1

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
    # 縮まない。⚠ ハンドラの中でも `/ffmpeg/timeout` の上限は効く（短いほうを取る）。
    # ハンドラの外（rake・テスト・CLI）では締切が無いので、上限だけが効く。
    def ffmpeg_timeout
      return [handler_deadline_remaining, ffmpeg_timeout_limit].compact.min
    end

    # ハンドラ締切までの残り。
    #
    # ⚠⚠ **単調時計で読む（PR #4706 の Codex P2）。**配る側（`Event#handler_deadline`）と
    # 物差しを揃える。壁時計を混ぜると NTP / VM の時刻補正で内外がずれる。
    # ⚠ 下限は `MIN_FFMPEG_TIMEOUT`。0 以下は `Timeout.timeout` が「制限なし」と読む。
    def handler_deadline_remaining
      return nil unless deadline = Thread.current[Event::HANDLER_DEADLINE_KEY]
      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return [remaining, MIN_FFMPEG_TIMEOUT].max
    end

    # ⚠⚠ **0 以下は既定へ倒す。**schema でも弾くが、`strict` が既定で偽なので
    # 起動は止まらない。`Timeout.timeout(0)` は「制限なし」なので、ここで塞がないと
    # 設定 1 行で #4696 の穴が開き直す。
    def ffmpeg_timeout_limit
      value = Config.instance['/ffmpeg/timeout']
      return value if value.is_a?(Numeric) && value.positive?
      return DEFAULT_FFMPEG_TIMEOUT
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
