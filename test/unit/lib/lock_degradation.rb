module Mulukhiya
  # ロックが「黙って効かなくなった」ことを観測できるか (#4577 の 2)。
  #
  # ⚠ fail-open 自体は正しい。見るのは 3 点:
  #
  # 1. 発動したことが **Sentry まで届く**か（従来は `e.log` 止まりで届かなかった）
  # 2. ⚠⚠ **毎分の周期実行で連打しない**か
  # 3. 🔴 ⚠⚠ **待たせない**か — `report` が `alert` ハンドラを同期で叩かないこと
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

    # ⚠ `report` は Sentry を叩くので、抑止の挙動を見るテストでは差し替える。
    # `report` の中身そのものは `test_report_does_not_dispatch_alert_handlers` が見る。
    def note(state, probe: @probe)
      record = @record
      unless probe.singleton_class.method_defined?(:report)
        probe.define_singleton_method(:report) {|_error, payload| record.push([:report, payload])}
      end
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
    def test_first_occurrence_escalates
      note(:fail_open)

      assert_equal([:report], kinds)
    end

    # ⚠⚠ 本丸その 2。2 回目以降は黙らせずに log へ落とす。
    # `Program#save` は ProgramUpdateWorker から **every 1m** で呼ばれるので、
    # 毎回上げると Redis 障害中に**日 1,440 件**のイベントになる
    # （#4573 で「周期実行の失敗をそのままアラートに載せない」と決めた形）。
    def test_repeat_falls_back_to_log
      3.times {note(:fail_open)}

      assert_equal([:report, :log, :log], kinds)
    end

    # ⚠⚠ **fail-open と release 失敗は別の鍵で抑える。**`EVAL` だけ通らない構成
    # （ACL / scripting 制限）では acquire が成功して release だけが毎回失敗する。
    # 同じ鍵にすると、fail-open が鳴っている間この別の障害が丸ごと黙る。
    def test_states_are_throttled_separately
      note(:fail_open)
      note(:release_failure)

      assert_equal([:report, :report], kinds)
    end

    # ⚠ ストレージ単位でも分ける。番組表のロックが鳴っている間に投稿テンプレの
    # ロックが黙るのも、別の障害を隠す。
    def test_storages_are_throttled_separately
      note(:fail_open)
      note(:fail_open, probe: Probe.new('other_lock'))

      assert_equal([:report, :report], kinds)
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

    # 🔴 **回帰。`report` は `StandardError#alert` へ行ってはいけない
    # （PR #4744 の Codex P2）。**あれは `Event#dispatch` まで行き、
    # slack / line / mail を**順番に同期で待つ**。
    #
    # ⚠⚠ **fail-open は「待たないための経路」で、しかも `release` 側は
    # 書き込みが commit 済み。**ここで待たせるとクライアントが先にタイムアウトして
    # 再送し、`increment_episode` のような**非冪等な操作が二度走る**。
    #
    # ⚠ Redis が落ちている状況は Slack / LINE / メールも届かない状況でありうる
    # ＝**全ハンドラが timeout まで粘る**のが最も起こりやすい組み合わせ。
    def test_report_does_not_dispatch_alert_handlers
      @probe.send(:report, error_double, lock: 'fail-open')

      assert_equal([:log], kinds, 'fail-open の経路から alert ハンドラを同期で叩いている')
    end
  end
end
