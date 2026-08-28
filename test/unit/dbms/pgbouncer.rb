module Mulukhiya
  # `PG.connect` の差し替え。⚠ **2 つのテストクラスで同じ細工が要る**ので、
  # #4654 の教訓どおり複写せず 1 本に寄せる。
  module PgbouncerStub
    def with_admin(admin)
      stub_connect {|**_params| admin}
      return yield
    ensure
      restore_connect
    end

    def with_failing_connect(message = 'refused')
      stub_connect {|**_params| raise PG::ConnectionBad, message}
      return yield
    ensure
      restore_connect
    end

    private

    def stub_connect(&)
      PG.singleton_class.alias_method(:__orig_connect, :connect)
      PG.define_singleton_method(:connect, &)
    end

    def restore_connect
      PG.singleton_class.alias_method(:connect, :__orig_connect)
      PG.singleton_class.remove_method(:__orig_connect)
    end
  end
end

module Mulukhiya
  # pgbouncer の待ち行列を /health に載せる (#4618 の P1)。
  #
  # ⚠⚠ **`Postgres.pool` はプロセスローカルの Sequel プールしか見ていない。**
  # 実際に枯れるのは Mastodon 本体・Sidekiq と共有する pgbouncer のほうで、
  # 2026-05-19 の全サーバー投稿不可も 2026-08-02 / 08-08 の枯渇も、そちらだった。
  class PgbouncerTest < TestCase
    include PgbouncerStub

    # admin コンソールのダブル。SHOW POOLS / SHOW LISTS / SHOW CONFIG を返す。
    class FakeAdmin
      attr_reader :closed, :queries

      def initialize(pools: nil, used_clients: 13, max_client_conn: 500, total_wait_time: 29_082_533)
        @pools = pools || [
          # ⚠ **自分の行より先に別の行が来る。**先頭を拾う実装だと取り違える。
          {'database' => 'other', 'user' => 'other', 'cl_active' => '99', 'cl_waiting' => '99',
           'sv_active' => '99', 'sv_idle' => '99', 'maxwait' => '99'},
          {'database' => 'mastodon', 'user' => 'mastodon', 'cl_active' => '12', 'cl_waiting' => '3',
           'sv_active' => '1', 'sv_idle' => '2', 'maxwait' => '7'},
          {'database' => 'pgbouncer', 'user' => 'pgbouncer', 'cl_active' => '1', 'cl_waiting' => '0',
           'sv_active' => '0', 'sv_idle' => '0', 'maxwait' => '0'},
        ]
        @used_clients = used_clients
        @max_client_conn = max_client_conn
        @total_wait_time = total_wait_time
        @queries = []
      end

      def exec(sql)
        @queries << sql
        case sql
        when 'SHOW POOLS' then return @pools
        when 'SHOW LISTS' then return [{'list' => 'databases', 'items' => '2'},
          {'list' => 'used_clients', 'items' => @used_clients.to_s}]
        when 'SHOW CONFIG' then return [{'key' => 'admin_users', 'value' => 'pgbouncer'},
          {'key' => 'max_client_conn', 'value' => @max_client_conn.to_s}]
        # ⚠ SHOW STATS の行は database 単位で user 列を持たない。
        when 'SHOW STATS' then return [{'database' => 'other', 'total_wait_time' => '99'},
          {'database' => 'mastodon', 'total_wait_time' => @total_wait_time.to_s}]
        end
        raise "unexpected query: #{sql}"
      end

      def close = @closed = true
    end

    def setup
      config['/postgres/dsn'] = 'postgres://mastodon:secret@127.0.0.1:6432/mastodon'
      config['/postgres/pgbouncer/enable'] = 'auto'
      config['/postgres/pgbouncer/timeout'] = 2
    end

    # ⚠ **素の PostgreSQL へ `pgbouncer` ユーザーで入りに行かない。**認証失敗が
    # /health を叩くたびに PostgreSQL のログへ溜まる。本番 4 台のうち vulcan が
    # 5432 直結（Misskey / Linux で cookbook の対象外）。
    def test_direct_postgres_is_not_probed
      config['/postgres/dsn'] = 'postgres://misskey@127.0.0.1:5432/misskey'

      assert_false(Pgbouncer.enable?)
      assert_empty(Pgbouncer.health)
    end

    def test_proxied_port_is_probed
      assert_predicate(Pgbouncer, :enable?)
    end

    # ポートを省略した DSN は素の PostgreSQL とみなす（自動判定の材料が無い）。
    def test_portless_dsn_is_not_probed
      config['/postgres/dsn'] = 'postgres://example.invalid/dummy'

      assert_false(Pgbouncer.enable?)
    end

    def test_explicit_config_overrides_auto_detection
      config['/postgres/pgbouncer/enable'] = false

      assert_false(Pgbouncer.enable?)

      config['/postgres/dsn'] = 'postgres://misskey@127.0.0.1:5432/misskey'
      config['/postgres/pgbouncer/enable'] = true

      assert_predicate(Pgbouncer, :enable?)
    end

    # ⚠⚠ **`cl_waiting` が本命。**サーバー接続を待ってブロックしているクライアント数で、
    # Mastodon 本体・モロヘイヤ Puma・Sidekiq の合算になる。
    def test_health_reports_the_shared_queue
      admin = FakeAdmin.new
      health = with_admin(admin) {Pgbouncer.health}

      assert_equal({
        database: 'mastodon',
        cl_active: 12,
        cl_waiting: 3,
        sv_active: 1,
        sv_idle: 2,
        maxwait: 7,
        clients_used: 13,
        clients_max: 500,
        total_wait_time_us: 29_082_533,
      }, health[:pgbouncer])
    end

    # ⚠ **自分と同じ (database, user) の行を選ぶ。**先頭や `pgbouncer` の管理行を
    # 拾うと、共有している待ち行列とは無関係の数字を報告する。
    def test_health_picks_the_row_for_our_own_dsn
      health = with_admin(FakeAdmin.new) {Pgbouncer.health}

      refute_equal(99, health.dig(:pgbouncer, :cl_waiting))
      assert_equal(3, health.dig(:pgbouncer, :cl_waiting))
    end

    # ⚠ **0 と「不明」は違う。**誰も繋いでいなければプールの行はまだ無い。
    # そこで 0 を報告すると「詰まっていない」と読めてしまう。
    def test_absent_pool_is_not_reported_as_zero
      admin = FakeAdmin.new(pools: [])
      health = with_admin(admin) {Pgbouncer.health}

      assert_predicate(health.dig(:pgbouncer, :absent), :present?)
      assert_nil(health.dig(:pgbouncer, :cl_waiting))
      # 箱全体のクライアント数は行が無くても読める。
      assert_equal(13, health.dig(:pgbouncer, :clients_used))
    end

    # ⚠ **2026-08-02 の gomander も 2026-08-08 の shallu も
    # `no more connections allowed (max_client_conn)`** で、枯れたのはプールごとの
    # 待ちではなく**箱全体のクライアント数**だった。上限との比較が要る。
    def test_health_reports_client_headroom
      admin = FakeAdmin.new(used_clients: 498, max_client_conn: 500)
      health = with_admin(admin) {Pgbouncer.health}

      assert_equal(498, health.dig(:pgbouncer, :clients_used))
      assert_equal(500, health.dig(:pgbouncer, :clients_max))
    end

    # ⚠ **繋がらないこと自体が信号になりうる**（max_client_conn 枯渇なら
    # 「no more connections allowed」が返る）。潰さずメッセージを出す。
    def test_connection_failure_is_reported_not_swallowed
      health = with_failing_connect('no more connections allowed (max_client_conn)') do
        Pgbouncer.health
      end

      assert_equal('no more connections allowed (max_client_conn)', health.dig(:pgbouncer, :error))
    end

    # ⚠⚠ **`cl_waiting` / `maxwait` は「いまキューに居る人」の値でしかない**
    # （PR #4671 の Codex P2）。pgbouncer の man は `maxwait` を "How long the first
    # (oldest) client in the queue has waited" と定義しており、**キューが捌けば
    # 両方 0 に戻る**。スクレイプの合間に起きて終わった詰まりが見えるのは、
    # 起動からの累計（単調増加）である `total_wait_time` のほうだけ。
    def test_finished_congestion_survives_in_the_cumulative_counter
      drained = FakeAdmin.new(
        pools: [{'database' => 'mastodon', 'user' => 'mastodon', 'cl_active' => '3',
                 'cl_waiting' => '0', 'sv_active' => '0', 'sv_idle' => '1', 'maxwait' => '0'}],
        total_wait_time: 1_500_000,
      )
      health = with_admin(drained) {Pgbouncer.health}

      # 瞬間値はどちらも 0 ＝ ここだけ見ると「詰まっていない」
      assert_equal(0, health.dig(:pgbouncer, :cl_waiting))
      assert_equal(0, health.dig(:pgbouncer, :maxwait))
      # 累計には残る。前回のスクレイプとの差分で「待ちが発生した」と分かる
      assert_equal(1_500_000, health.dig(:pgbouncer, :total_wait_time_us))
    end

    # ⚠ SHOW STATS も自分の database の行を選ぶ。
    def test_cumulative_counter_picks_our_own_database
      health = with_admin(FakeAdmin.new) {Pgbouncer.health}

      refute_equal(99, health.dig(:pgbouncer, :total_wait_time_us))
    end

    def test_connection_is_closed
      admin = FakeAdmin.new
      with_admin(admin) {Pgbouncer.health}

      assert(admin.closed)
    end

    # ⚠ クエリの途中で落ちても接続を残さない。
    def test_connection_is_closed_on_error
      admin = FakeAdmin.new
      admin.define_singleton_method(:exec) {|_sql| raise 'boom'}
      with_admin(admin) {Pgbouncer.health}

      assert(admin.closed)
    end
  end

  # pgbouncer の観測は health の status を動かさない (#4618)。
  #
  # ⚠⚠ **pgbouncer の停止と枯渇は接続失敗からは区別できない。**status を倒すと
  # 再起動のたびに health が揺れて、逆に信号として使えなくなる。
  class PgbouncerDoesNotFlipStatusTest < TestCase
    include PgbouncerStub

    # ⚠ PostgresTest のダブルを借りない。`bin/test.rb pgbouncer` のように
    # 1 ケースだけ回すと向こうが読み込まれず、**テストの都合で落ちる**。
    class FakePool
      def max_size = 10
      def size = 2
      def num_waiting = 0
    end

    class FakeConnection
      def pool = FakePool.new
      def fetch(_sql) = [{ok: 1}]
    end

    class FakeInstance
      def connection = FakeConnection.new
    end

    def setup
      config['/postgres/dsn'] = 'postgres://mastodon:secret@127.0.0.1:6432/mastodon'
      config['/postgres/pgbouncer/enable'] = 'auto'
      config['/postgres/pgbouncer/timeout'] = 2
      Postgres.instance_variable_set(:@singleton__instance__, FakeInstance.new)
    end

    def teardown
      Singleton.__init__(Postgres)
      super
    end

    def test_status_stays_ok_when_pgbouncer_is_unreachable
      health = with_failing_connect {Postgres.health}

      assert_equal('OK', health[:status])
      assert_equal({max: 10, allocated: 2, waiting: 0}, health[:pool])
      assert_predicate(health.dig(:pgbouncer, :error), :present?)
    end
  end
end
