module Mulukhiya
  class MediaFile < File
    include Package
    extend MediaFileDownloadMethods

    # ffmpeg 1 回あたりの上限 (秒)。`/ffmpeg/timeout` が読めないときの既定。
    # ⚠ ハンドラの中では `Event::HANDLER_DEADLINE_KEY` の残りと**短いほう**が効く。
    DEFAULT_FFMPEG_TIMEOUT = 90

    # 内側へ渡す下限 (秒)。⚠ **0 以下を渡さない** — `Timeout.timeout(0)` は
    # 「制限なし」の意味になり、塞いだはずの穴がそのまま開く。
    # ⚠ 1 秒ではなくこの値なのは、`timeout` に数秒を設定したハンドラで
    # **下限が締切そのものを追い越さない**ようにするため（PR #4706 の Codex P2）。
    MIN_FFMPEG_TIMEOUT = 0.1

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
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    alias convert_format convert_type

    # 変換の出力先。
    #
    # ⚠⚠ **呼び出しごとに一意にする (#4722)。**以前は内容の sha256 から決まる固定名で、
    # 同じ動画・画像がほぼ同時に 2 回上がる（連投・webhook の再送）と、片方が
    # アップロード中のファイルをもう片方の ffmpeg (`-y`) / vips が上書き・切り詰め
    # えた。#4626 で取得側を `write_atomic` にしたのと同じ問題。出力を使い回す
    # 呼び出し元は無いので、名前を分けるだけで足りる。
    # ⚠ **拡張子は末尾に保つ。**ffmpeg も vips も拡張子で出力形式を決める。
    # ⚠ ドット始まりにしない（`MediaFile.all` の掃除は `*` glob）。
    def create_dest_path(params = {})
      params[:extname] ||= MIMEType.extname(params[:type])
      params[:extname] ||= ".#{default_mediatype}"
      params[:content] = File.read(path).sha256
      return File.join(
        Environment.dir,
        'tmp/media',
        "#{params[:content]}-#{SecureRandom.hex(8)}#{params[:extname]}",
      )
    end

    def video_stream
      unless @video
        command = FFmpegCommandBuilder.probe_video(path)
        command.exec(timeout: probe_timeout)
        @video = JSON.parse(command.stdout)['streams'].first
      end
      return @video
    end

    def audio_stream
      unless @audio
        command = FFmpegCommandBuilder.probe_audio(path)
        command.exec(timeout: probe_timeout)
        @audio = JSON.parse(command.stdout)['streams'].first
      end
      return @audio
    end

    def container
      unless @container
        command = FFmpegCommandBuilder.probe_container(path)
        command.exec(timeout: probe_timeout)
        @container = JSON.parse(command.stdout)
      end
      return @container
    end

    # ffprobe 1 回あたりの締切 (秒)。
    #
    # ⚠ **ハンドラの締切も見る (#4722)。**以前は `/ffmpeg/probe/timeout` 固定で、
    # ハンドラの timeout をそれより短くすると外側の `thread.join` が先に発火し、
    # `{message: 'timeout'}` 1 行しか残らなかった。ffmpeg と同じく短いほうを取る。
    def probe_timeout
      return [handler_deadline_remaining, probe_timeout_limit].compact.min
    end

    def self.purge
      worker = Worker.create(:media_cleaning)
      time = worker.worker_config(:hours).hours.ago
      deletable_files = all.select {|f| File.new(f).mtime < time}
      Parallel.each(deletable_files, in_threads: Parallel.processor_count * 2) do |path|
        FileUtils.rm_rf(path)
        logger.info(class: to_s, method: __method__, path:)
      rescue => e
        e.log(path:)
      end
      blank_dirs.each {|v| FileUtils.rm_rf(v)}
    end

    def self.all(&block)
      return enum_for(__method__) unless block
      finder = Ginseng::FileFinder.new
      finder.dir = File.join(Environment.dir, 'tmp/media')
      finder.patterns.push('*')
      finder.exec.select {|f| FileTest.file?(f)}.each(&block)
    end

    def self.blank_dirs(&block)
      return enum_for(__method__) unless block
      finder = Ginseng::FileFinder.new
      finder.dir = File.join(Environment.dir, 'tmp/media')
      finder.patterns.push('*')
      finder.exec
        .select {|path| FileTest.directory?(path)}
        .select {|path| Dir.new(path).entries.length == 2}
        .each(&block)
    end

    private

    def probe_timeout_limit
      return Config.instance['/ffmpeg/probe/timeout']
    rescue
      return 30
    end

    # ffmpeg 1 回あたりの締切 (秒)。動画・音声の変換で使う。
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
  end
end
