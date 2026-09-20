module Mulukhiya
  # ロックが「黙って効かなくなった」ことを観測できるか (#4577 の 2)。
  #
  # ⚠ fail-open 自体は正しい。見るのは **発動したことが Sentry まで届くか**と、
  # ⚠⚠ **毎分の周期実行で連打しないか**の両方。どちらか片方だけ満たす実装
  # （常に log / 常に alert）はどちらも過去に踏んでいる。
  class LockDegradationTest < TestCase
    # 本物の Redis を要らなくするための最小の受け皿。`underscore` だけ要る。
    class Probe
      include Package
      include LockDegradationMethods

      def initialize(name)
        @name = name
      end

      def underscore
        return @name
      end
    end

    def setup
      LocalAlertThrottle.clear(LockDegradationMethods::THROTTLE_KEY_PREFIX)
      @probe = Probe.new('probe_lock')
      @record = []
    end

    def teardown
      LocalAlertThrottle.clear(LockDegradationMethods::THROTTLE_KEY_PREFIX)
    end

    def note(state, probe: @probe)
      probe.send(:"note_#{state}", error_double)
    end

    def error_double
      record = @record
      double = Object.new
      double.define_singleton_method(:log) {|payload| record.push([:log, payload])}
      double.define_singleton_method(:alert) {|payload| record.push([:alert, payload])}
      return double
    end

    def kinds
      return @record.map(&:first)
    end

    # ⚠⚠ 本丸その 1。1 回目は鳴る。⚠ 従来は `e.log` 止まりで
    # **Sentry に 1 件も届かなかった**ので、ロックが無効化されたことを
    # 知る手段がゼロだった。
    def test_first_occurrence_alerts
      note(:fail_open)

      assert_equal([:alert], kinds)
    end

    # ⚠⚠ 本丸その 2。2 回目以降は黙らせずに log へ落とす。
    # `Program#save` は ProgramUpdateWorker から **every 1m** で呼ばれるので、
    # ここが alert のままだと Redis 障害中に**日 1,440 件**鳴る
    # （#4573 で「周期実行の失敗をそのままアラートに載せない」と決めた形）。
    def test_repeat_falls_back_to_log
      3.times {note(:fail_open)}

      assert_equal([:alert, :log, :log], kinds)
    end

    # ⚠⚠ **fail-open と release 失敗は別の鍵で抑える。**`EVAL` だけ通らない構成
    # （ACL / scripting 制限）では acquire が成功して release だけが毎回失敗する。
    # 同じ鍵にすると、fail-open が鳴っている間この別の障害が丸ごと黙る。
    def test_states_are_throttled_separately
      note(:fail_open)
      note(:release_failure)

      assert_equal([:alert, :alert], kinds)
    end

    # ⚠ ストレージ単位でも分ける。番組表のロックが鳴っている間に投稿テンプレの
    # ロックが黙るのも、別の障害を隠す。
    def test_storages_are_throttled_separately
      note(:fail_open)
      note(:fail_open, probe: Probe.new('other_lock'))

      assert_equal([:alert, :alert], kinds)
    end

    # ⚠ どちらの事象か・どのストレージかがペイロードから読めること。
    # 「ロック無しで書いた」ことを後から追える唯一の手掛かりになる。
    def test_payload_names_the_state_and_storage
      note(:fail_open)
      payload = @record.last[1]

      assert_equal('fail-open', payload[:lock])
      assert_equal('probe_lock', payload[:storage])
    end

    def test_release_failure_is_named
      note(:release_failure)

      assert_equal('release-failed', @record.last[1][:lock])
    end

    # ⚠ 呼び出し側が渡した値（account_id 等）を落とさない。
    def test_extra_values_are_kept
      @probe.send(:note_fail_open, error_double, account_id: 42)

      assert_equal(42, @record.last[1][:account_id])
    end

    # ⚠⚠ **`alert` は内部で `log` も撃つ**（`StandardError#alert`）。
    # 両方呼ぶと syslog が二重になるので、鳴らした回は log を重ねない。
    def test_alert_does_not_double_log
      note(:fail_open)

      assert_equal(1, @record.size)
    end
  end
end
