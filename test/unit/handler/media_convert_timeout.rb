module Mulukhiya
  # 変換の締切切れ (#4722)。
  #
  # ⚠ 長い動画 1 本ごとに Sentry と slack / line / mail が鳴っていた。締切切れだけを
  # ハンドラごとに窓 1 回へ間引き、ほかの失敗は従来どおり毎回鳴らす。
  # ⚠ 間引きの印（`AlertThrottle.acquire`）は差し替える。Redis も ffmpeg も要らない。
  class MediaConvertTimeoutTest < TestCase
    FIXTURE = File.join(Environment.dir, 'public/mulukhiya/media/h264.mkv')

    def setup
      @slots = Set.new
      slots = @slots
      AlertThrottle.singleton_class.alias_method(:__orig_acquire, :acquire)
      AlertThrottle.define_singleton_method(:acquire) {|key, _ttl| !slots.add?(key).nil?}
    end

    def teardown
      super
      AlertThrottle.singleton_class.alias_method(:acquire, :__orig_acquire)
      AlertThrottle.singleton_class.remove_method(:__orig_acquire)
    end

    def test_timeout_alerts_once_per_window
      handler = create_handler
      calls = Array.new(2) {pass_through(handler, Timeout::Error.new('execution expired (85s)'))}

      assert_equal([:alert, :log], calls)
      assert_equal(['Timeout::Error'] * 2, handler.errors.map {|e| e[:class]})
    end

    # 間引くのは締切切れだけ。本物の失敗は毎回鳴らす。
    def test_other_errors_always_alert
      handler = create_handler
      calls = Array.new(2) {pass_through(handler, RuntimeError.new('ffmpeg failed'))}

      assert_equal([:alert, :alert], calls)
    end

    # 窓はハンドラごと。動画の締切切れが、音声の締切切れの 1 回目を握り潰さない。
    def test_window_is_per_handler
      video = pass_through(create_handler(:video_format_convert), Timeout::Error.new)
      audio = pass_through(create_handler(:audio_format_convert), Timeout::Error.new)

      assert_equal([:alert, :alert], [video, audio])
    end

    # 締切切れは `status` が nil のまま例外になる。どの段で切れたかを残してから上げ直す。
    def test_video_file_logs_phase_on_timeout
      file = VideoFile.new(FIXTURE)
      lines = []
      fake_logger = Object.new
      fake_logger.define_singleton_method(:error) {|values| lines.push(values)}
      file.define_singleton_method(:logger) {fake_logger}
      command = Object.new
      command.define_singleton_method(:exec) {|**| raise Timeout::Error, 'execution expired'}
      command.define_singleton_method(:status) {nil}
      command.define_singleton_method(:stderr) {nil}

      assert_raise(Timeout::Error) {file.send(:run_ffmpeg, command, 'transcode')}
      assert_equal(['transcode'], lines.map {|v| v[:phase]})
    end

    private

    def create_handler(name = :video_format_convert)
      handler = Handler.create(name, sns: Object.new)
      handler.define_singleton_method(:convertable?) {true}
      return handler
    end

    # ハンドラを 1 回通し、例外が alert / log のどちらへ行ったかを返す。
    def pass_through(handler, error)
      called = []
      error.define_singleton_method(:alert) {|*| called.push(:alert)}
      error.define_singleton_method(:log) {|*| called.push(:log)}
      handler.define_singleton_method(:convert) {raise error}
      handler.handle_pre_upload(file: {tempfile: File.new(FIXTURE)})
      return called.first
    end
  end
end
