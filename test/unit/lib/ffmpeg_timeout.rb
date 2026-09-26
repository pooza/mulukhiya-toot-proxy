module Mulukhiya
  # ffmpeg の内側の締切が、**ハンドラ締切より先に発火する**こと (#4696)。
  #
  # ⚠⚠ **直す前は内外とも `/handler/video_format_convert/timeout` = 90 を読んでいた。**
  # 外側の `Event#run_handler` の `thread.join(handler.timeout)` が先に始まり、しかも
  # transcode の前に `video_stream` のプローブ（`/ffmpeg/probe/timeout` = 30）が
  # 挟まるので、**内側の `Timeout.timeout(90)` は構造的に一度も発火しなかった**。
  # ⚠ 発火しないと `log_ffmpeg_error` と `raise "ffmpeg failed: ..."` の経路ごと死に、
  # 残るのは `{message: 'timeout'}` 1 行だけになる。
  class FFmpegTimeoutTest < TestCase
    HANDLER_TIMEOUT = 90

    def setup
      @file = VideoFile.allocate
      @deadline = Thread.current[Event::HANDLER_DEADLINE_KEY]
    end

    def teardown
      Thread.current[Event::HANDLER_DEADLINE_KEY] = @deadline
    end

    # 🔴 **本体。**ハンドラ締切から逆算した残りが、**必ずハンドラ締切より短い**。
    # ⚠ プローブに上限いっぱい掛かった最悪ケースでも内側が先に切れること。
    def test_inner_deadline_always_precedes_the_handler
      publish(HANDLER_TIMEOUT)

      assert_operator(timeout, :<, HANDLER_TIMEOUT)

      # プローブが上限（30 秒）を使い切った後でも成り立つ。
      Thread.current[Event::HANDLER_DEADLINE_KEY] -= probe_timeout

      assert_operator(timeout, :<, HANDLER_TIMEOUT - probe_timeout)
    end

    # 🔴 **`Timeout.timeout(0)` は「制限なし」**なので、0 以下を渡してはいけない。
    # ⚠ 締切を過ぎていても穴が開かないこと。
    def test_expired_deadline_never_disables_the_timeout
      Thread.current[Event::HANDLER_DEADLINE_KEY] = monotonic - 3600

      assert_operator(timeout, :>, 0)
    end

    # ハンドラの外（rake・CLI・テスト）では締切が無いので上限だけが効く。
    def test_falls_back_to_the_limit_outside_a_handler
      Thread.current[Event::HANDLER_DEADLINE_KEY] = nil

      assert_equal(config['/ffmpeg/timeout'], timeout)
    end

    # ⚠ 締切が上限より遠くても、上限を超えない。
    def test_limit_caps_a_distant_deadline
      Thread.current[Event::HANDLER_DEADLINE_KEY] = monotonic + 100_000

      assert_equal(config['/ffmpeg/timeout'], timeout)
    end

    # ⚠⚠ **ハンドラ締切と同じ設定値を読み戻していないこと。**ここが同じ値に戻ったら
    # 「内側が発火しない」に逆戻りする。
    def test_does_not_read_the_handler_timeout_key
      Thread.current[Event::HANDLER_DEADLINE_KEY] = nil
      config['/handler/video_format_convert/timeout'] = 12_345

      assert_not_equal(12_345, timeout)
    ensure
      config['/handler/video_format_convert/timeout'] = HANDLER_TIMEOUT
    end

    # 🔴 **`/ffmpeg/timeout` に 0 以下を書いても「制限なし」にならない。**
    # ⚠ schema でも弾くが、`strict` が既定で偽なので起動は止まらない。
    # 設定 1 行で #4696 の穴が開き直すので、コードの側でも既定へ倒す。
    def test_non_positive_limit_falls_back_to_the_default
      Thread.current[Event::HANDLER_DEADLINE_KEY] = nil
      [0, -1].each do |value|
        config['/ffmpeg/timeout'] = value

        assert_equal(VideoFile::DEFAULT_FFMPEG_TIMEOUT, timeout, "#{value} で制限が外れる")
      end
    ensure
      config['/ffmpeg/timeout'] = VideoFile::DEFAULT_FFMPEG_TIMEOUT
    end

    # ⚠ schema でも 0 以下は誤りとして出る（`rake config:lint` で気づける）。
    def test_schema_rejects_a_non_positive_limit
      errors = JSON::Validator.fully_validate(config.schema, {'ffmpeg' => {'timeout' => 0}})

      assert(errors.any? {|e| e.include?('#/ffmpeg/timeout')}, '0 を schema が通している')
    end

    # 🔴 `Event#run_handler` が実際に締切をスレッドへ配ること。
    # ⚠ 配線が外れても VideoFile 側のテストだけでは緑のままになる（#4583 と同型）。
    def test_run_handler_publishes_the_deadline
      seen = nil
      handler = Object.new
      handler.define_singleton_method(:timeout) {HANDLER_TIMEOUT}
      handler.define_singleton_method(:handle_pre_toot) do |_payload, _params|
        seen = Thread.current[Event::HANDLER_DEADLINE_KEY]
      end

      Event.new(:pre_toot).send(:run_handler, handler, {}, nil)

      assert_not_nil(seen, '締切がスレッドへ配られていない')
      assert_operator(seen - monotonic, :<=, HANDLER_TIMEOUT - Event::HANDLER_DEADLINE_MARGIN)
    end

    # 🔴 **短いハンドラ締切でも内側が先に切れる**（PR #4706 の Codex P2）。
    # ⚠ 余白をそのまま引くと `timeout` が 1〜5 秒のとき締切が既に過ぎた時刻になり、
    # 内側が下限へ張り付いて**外側が先に発火しうる**。
    def test_short_handler_timeout_keeps_a_positive_lead
      [1, 2, 5].each do |seconds|
        publish(seconds)

        assert_operator(timeout, :>, 0, "#{seconds}s: 0 以下は制限なしになる")
        assert_operator(timeout, :<, seconds, "#{seconds}s: 内側が外側を追い越している")
      end
    end

    # ⚠⚠ **単調時計で持つ**（PR #4706 の Codex P2）。壁時計だと NTP / VM の補正で
    # 内外の物差しがずれ、後ろへ飛べば内側が外側に追い越される。
    def test_deadline_is_monotonic
      publish(HANDLER_TIMEOUT)
      deadline = Thread.current[Event::HANDLER_DEADLINE_KEY]

      # 壁時計基準なら epoch 秒（10^9 台）になる。単調時計は起動からの経過。
      assert_in_delta(monotonic + HANDLER_TIMEOUT - Event::HANDLER_DEADLINE_MARGIN, deadline, 1)
      assert_operator(deadline, :<, Time.now.to_f, '壁時計基準になっている')
    end

    # 🔴 **音声変換も締切を見る (#4722)。**以前は `AudioFile#convert_type` の
    # `exec` に timeout が無く、audio_format_convert（30 秒）の内側は #4696 と同じく
    # 一度も発火しなかった。remux が失敗して transcode へ進む経路も含めて見る。
    def test_audio_convert_passes_the_deadline_to_ffmpeg
      publish(HANDLER_TIMEOUT)
      mp3 = File.join(Environment.dir, 'public/mulukhiya/media/hugttocatch.mp3')
      timeouts = []
      stub_builder(:remux_audio, timeouts, status: 1) do
        stub_builder(:transcode_audio, timeouts, status: 0) do
          AudioFile.new(mp3).convert_type('audio/mpeg')
        end
      end

      assert_equal(2, timeouts.size)
      timeouts.each do |value|
        assert_not_nil(value, 'timeout なしで ffmpeg を撃っている')
        assert_operator(value, :<, HANDLER_TIMEOUT)
      end
    end

    # 🔴 **ffprobe も締切を見る (#4722)。**`probe_timeout` は 30 秒固定だったので、
    # ハンドラの timeout を 30 秒未満にすると外側が先に発火し、`{message: 'timeout'}`
    # しか残らなかった。
    def test_probe_timeout_respects_the_deadline
      Thread.current[Event::HANDLER_DEADLINE_KEY] = monotonic + 5

      assert_operator(@file.probe_timeout, :<=, 5)
      assert_operator(@file.probe_timeout, :>, 0)
    end

    # ハンドラの外では従来どおり `/ffmpeg/probe/timeout` が効く。
    def test_probe_timeout_falls_back_to_the_limit_outside_a_handler
      Thread.current[Event::HANDLER_DEADLINE_KEY] = nil

      assert_equal(probe_timeout, @file.probe_timeout)
    end

    private

    # FFmpegCommandBuilder の生成メソッドを差し替え、`exec` に渡った timeout を
    # 集める。出力先には元ファイルを複製して、変換後の `new(dest)` を通す。
    # ⚠ 必ず元へ戻すこと（残すと以後のテストが本物の ffmpeg を撃たなくなる）。
    def stub_builder(name, timeouts, status:)
      original = FFmpegCommandBuilder.method(name)
      FFmpegCommandBuilder.define_singleton_method(name) do |src, dest, *_args|
        command = Object.new
        command.define_singleton_method(:exec) do |timeout: nil|
          timeouts.push(timeout)
          FileUtils.cp(src, dest)
        end
        command.define_singleton_method(:status) {status}
        command
      end
      return yield
    ensure
      FFmpegCommandBuilder.singleton_class.send(:remove_method, name)
      FFmpegCommandBuilder.define_singleton_method(name, original)
    end

    def monotonic
      return Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # `Event#run_handler` が配るのと同じ形で締切を置く。
    def publish(handler_timeout)
      Thread.current[Event::HANDLER_DEADLINE_KEY] =
        Event.new(:pre_toot).send(:handler_deadline, handler_timeout)
    end

    def timeout
      return @file.send(:ffmpeg_timeout)
    end

    def probe_timeout
      return config['/ffmpeg/probe/timeout']
    end
  end
end
