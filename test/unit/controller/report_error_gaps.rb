module Mulukhiya
  # `report_error` の過不足を塞いだこと (#4693)。
  #
  # ⚠⚠ **#4654 の一本化でステータスだけの判断になった。**その結果、
  # **ステータスと重大さがずれる 3 系統**でおかしくなっていた。
  class ReportErrorGapsTest < TestCase
    THROTTLED_CLASSES = [
      RuntimeError, ArgumentError, Ginseng::CryptError, Ginseng::AuthError
    ].freeze

    def setup
      @controller = APIController.new!
      clear_alert_throttle(*THROTTLED_CLASSES)
    end

    def teardown
      clear_alert_throttle(*THROTTLED_CLASSES)
    end

    # 🔴 **① 印が付いていればステータスに依らず必ず鳴らす。**
    # ⚠ `Ginseng::CryptError#status` は 403 なので、素だと `log` 止めになる。
    def test_never_silent_marker_beats_the_status
      error = NeverSilent.mark(Ginseng::CryptError.new('crypt broken'))

      assert_equal(:alert, report(error))
    end

    # ⚠ 印が無ければ従来どおり。403 は log 止め。
    def test_unmarked_client_error_stays_logged
      assert_equal(:log, report(Ginseng::CryptError.new('crypt broken')))
    end

    # 🔴 **② `token_mismatch` は必ず鳴る。**セキュリティ不変条件の破れ。
    def test_token_mismatch_is_never_silent
      error = NeverSilent.mark(Ginseng::AuthError.new('Token integrity check failed'))

      assert_equal(:alert, report(error))
    end

    # ⚠ 素の `AuthError`（トークン期限切れ等）は従来どおり log 止め。
    def test_plain_auth_error_stays_logged
      assert_equal(:log, report(Ginseng::AuthError.new('Unauthorized')))
    end

    # 🔴 **③ サーバー側の失敗は 1 回目だけ鳴る。**
    # ⚠⚠ **`before` は全リクエストで走る。**素通しだと DB 全断中にリクエスト
    # 1 本ごとに Sentry ＋ slack / line / mail が飛ぶ。
    def test_server_error_alerts_once_then_throttles
      error = RuntimeError.new('db is down')

      assert_equal(:alert, report(error), '1 回目が鳴っていない')
      assert_equal(:log, report(error), '2 回目が抑えられていない')
      assert_equal(:log, report(error))
    end

    # ⚠ 型ごとに独立して数える。連打を抑えている間に別の型（本物のバグ）が
    # 出たら、そちらは 1 回目として鳴ってほしい。
    def test_throttle_is_per_error_class
      assert_equal(:alert, report(RuntimeError.new('db is down')))

      assert_equal(:alert, report(ArgumentError.new('a real bug')), '別の型まで抑えている')
    end

    # ⚠ 印が付いていれば抑止も掛からない（必ず鳴らす、が優先）。
    def test_marked_errors_are_not_throttled
      error = NeverSilent.mark(Ginseng::CryptError.new('crypt broken'))

      assert_equal(:alert, report(error))
      assert_equal(:alert, report(error), '印が付いているのに抑えられている')
    end

    # 🔴 **抑止は発生源ごと（PR #4712 の Codex P2）。**
    # ⚠⚠ `report_error` は `before` だけでなく**各コントローラの rescue から
    # 呼ばれる**ので、型だけで括ると **`RuntimeError` のような広い型で、あるルートの
    # 失敗が別ルートの本物のバグを 300 秒握り潰す。**
    def test_throttle_is_scoped_to_the_origin
      error = RuntimeError.new('boom')

      assert_equal(:alert, report_from(error, 'POST /api/v?/status/tags'))
      assert_equal(:log, report_from(error, 'POST /api/v?/status/tags'), '同じルートが抑えられていない')
      assert_equal(:alert, report_from(error, 'GET /api/v?/about'), '別ルートまで抑えている')
    ensure
      clear_alert_throttle(RuntimeError)
    end

    # ⚠ ルートが決まる前（`before`）は 1 つのバケツ。**パスごとに分けると
    # 分けた数だけ鳴る**＝抑えたい相手そのものを取り逃がす。
    def test_before_failures_share_one_bucket
      error = RuntimeError.new('db is down')

      assert_equal(:alert, report_from(error, nil))
      assert_equal(:log, report_from(error, nil))
    ensure
      clear_alert_throttle(RuntimeError)
    end

    # 🔴 **Redis に印を書けなくても黙らない（5.37.0 リリース前レビューの赤）。**
    #
    # ⚠⚠ **当初はここで log へ倒していた**（「Redis の死は /health が見る」前提）。
    # だが **書き込みを拒む Redis（ディスク満杯の MISCONF・OOM・READONLY）では
    # `/health` の redis は OK のまま**（読みしか試さない）で、印が永遠に書けないので
    # **全ルートのサーバー側失敗が 1 回も鳴らなくなっていた**（観測性の観点が再現）。
    # → プロセス内の抑止へ倒す。**1 回目は鳴り、2 回目以降は抑える。**
    def test_does_not_go_silent_when_redis_refuses_writes
      refuse_redis_writes
      error = RuntimeError.new('db is down')

      assert_equal(:alert, report(error), 'Redis に書けないと 1 回も鳴らない（黙る）')
      assert_equal(:log, report(error), 'Redis に書けないと毎回鳴る（連打する）')
    ensure
      restore_redis_client
    end

    # ⚠⚠ **`KEYS` を撃たない。**`Ginseng::Redis::Service#key?` の中身は `KEYS` で、
    # DB 全体を O(N) で走査して Redis を塞ぐ。障害の最中に要求のたびに撃つと、
    # Mastodon と共有しているインスタンスごと障害を悪化させる。
    def test_does_not_scan_the_keyspace
      scanned = false
      Redis.define_method(:keys) do |*|
        scanned = true
        []
      end
      Redis.define_method(:key?) do |*|
        scanned = true
        false
      end

      report(RuntimeError.new('db is down'))

      refute(scanned, 'KEYS（key? / keys）を撃っている')
    ensure
      Redis.send(:remove_method, :keys) if Redis.method_defined?(:keys, false)
      Redis.send(:remove_method, :key?) if Redis.method_defined?(:key?, false)
    end

    # ⚠ **再送の sleep を払わない。**ginseng-redis の `setex` は失敗すると 1 秒ずつ
    # 待って再送するので、書き込みを拒む Redis では 5xx のたびに約 2 秒止まっていた。
    def test_does_not_sleep_when_redis_refuses_writes
      refuse_redis_writes
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      report(RuntimeError.new('db is down'))

      assert_operator(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 0.5)
    ensure
      restore_redis_client
    end

    private

    # **読みは通し、書きだけ拒む** Redis（MISCONF・OOM・READONLY の再現）。
    #
    # ⚠ **Redis クライアントの層で差し替える。**`Mulukhiya::Redis#acquire` を
    # 差し替えると、`key?` → `setex` を使う旧実装の経路では何も起きず、
    # **旧実装でもテストが通ってしまう**（実際に false negative を踏んだ）。
    # 新旧どちらの実装も通る `redis.call` で拒めば、旧実装は実際に黙り・止まる。
    def refuse_redis_writes
      client = Object.new
      client.define_singleton_method(:call) do |command, *_args|
        raise RedisClient::CommandError, 'READONLY You can\'t write against a read only replica.' \
          if ['SET', 'SETEX'].include?(command.to_s.upcase)
        return [] if command.to_s.upcase == 'KEYS'
        return nil
      end
      Redis.alias_method(:__orig_redis_client, :redis)
      Redis.define_method(:redis) {client}
    end

    def restore_redis_client
      return unless Redis.private_method_defined?(:__orig_redis_client) ||
        Redis.method_defined?(:__orig_redis_client)
      Redis.alias_method(:redis, :__orig_redis_client)
      Redis.send(:remove_method, :__orig_redis_client)
    end

    # 発生源（`sinatra.route`）を指定して呼ぶ。
    def report_from(error, route)
      env = route ? {'sinatra.route' => route} : {}
      @controller.define_singleton_method(:request) do
        @probe_request ||= {}
        @probe_request[route] ||= Struct.new(:env).new(env)
      end
      return report(error)
    end

    # `log` / `alert` のどちらが呼ばれたかだけを見る。
    def report(error)
      called = nil
      error.define_singleton_method(:log) {|*| called = :log}
      error.define_singleton_method(:alert) {|*| called = :alert}
      @controller.report_error(error)
      return called
    end
  end
end
