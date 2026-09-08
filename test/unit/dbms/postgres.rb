module Mulukhiya
  class PostgresTest < TestCase
    class FakePool
      attr_reader :max_size, :size, :num_waiting

      def initialize(max: 10, size: 3, waiting: 0)
        @max_size = max
        @size = size
        @num_waiting = waiting
      end
    end

    # 「使用中の本数」しか持たない旧来のプール実装 (num_waiting なし) を模す。
    class FakeLegacyPool < FakePool
      undef_method :num_waiting
    end

    # `SELECT 1` を待っている間に待ち行列が捌けるプールを模す (#4618)。
    # ⚠ **これが起きると、観測を後から取る実装は「詰まっていない」と報告する。**
    class DrainingPool < FakePool
      def initialize(...)
        super
        @drained = false
      end

      def drain
        @drained = true
      end

      def num_waiting
        return 0 if @drained

        return super
      end
    end

    class FakeConnection
      attr_reader :disconnected
      attr_writer :pool

      def initialize(pool = nil)
        @pool = pool
      end

      def disconnect
        @disconnected = true
      end

      def pool
        raise 'no pool' unless @pool
        return @pool
      end

      def fetch(_sql)
        @pool.drain if @pool.respond_to?(:drain)
        return [{ok: 1}]
      end
    end

    class FakeInstance
      attr_reader :connection

      def initialize(connection)
        @connection = connection
      end
    end

    def teardown
      Singleton.__init__(Postgres)
      super
    end

    def stub_instance(pool)
      Postgres.instance_variable_set(
        :@singleton__instance__,
        FakeInstance.new(FakeConnection.new(pool)),
      )
    end

    def test_connected_reflects_singleton_state
      Singleton.__init__(Postgres)

      assert_false(Postgres.connected?)

      Postgres.instance_variable_set(:@singleton__instance__, FakeInstance.new(FakeConnection.new))

      assert_predicate(Postgres, :connected?)
    end

    # config['/postgres/dsn'] 未設定なら reconnect は既存接続を切って singleton を
    # リセットし、再接続は試みない (connect が nil を返す)。
    def test_reconnect_disconnects_and_resets_existing_instance
      config['/postgres/dsn'] = nil
      conn = FakeConnection.new
      Postgres.instance_variable_set(:@singleton__instance__, FakeInstance.new(conn))

      assert_nil(Postgres.reconnect)
      assert(conn.disconnected)
      assert_false(Postgres.connected?)
    end

    # ⚠ **枯渇してからでは遅い (#4351 Gate 2)。**従来の health は PoolTimeout を
    # 掴んだときだけ pool_exhausted を出す＝もう詰まっている状態しか見えなかった。
    def test_pool_reports_capacity_and_waiting
      stub_instance(FakePool.new(max: 10, size: 3, waiting: 0))

      assert_equal({pool: {max: 10, allocated: 3, waiting: 0}}, Postgres.pool)
    end

    # ⚠ waiting が本命の指標。allocated が max に張り付くのは正常（使い回す設計）で、
    # 待ちが立ったときだけプールが要求に足りていない。
    def test_pool_reports_waiting_threads
      stub_instance(FakePool.new(max: 10, size: 10, waiting: 4))

      assert_equal(4, Postgres.pool.dig(:pool, :waiting))
    end

    # num_waiting を持たないプール実装ではキーごと落とす（nil を出さない）。
    def test_pool_omits_waiting_when_unsupported
      stub_instance(FakeLegacyPool.new(max: 10, size: 3))

      assert_equal({pool: {max: 10, allocated: 3}}, Postgres.pool)
    end

    # ⚠ 観測が取れないこと自体で health を落とさない。
    def test_pool_is_empty_when_unavailable
      stub_instance(nil)

      assert_empty(Postgres.pool)
    end

    # ⚠ **回帰テスト (#4618)。**観測を `SELECT 1` の後に取る実装だと、
    # health 自身が待ち行列に並んでいる間に前の待ちが捌けて `waiting: 0` に化ける。
    # **有限のスパイクだけが見えない**ので、Gate 2 の rollback 信号として使えない。
    def test_health_reports_pool_state_before_the_probe_query
      config['/postgres/dsn'] = 'postgres://example.invalid/dummy'
      stub_instance(DrainingPool.new(max: 10, size: 10, waiting: 5))
      health = Postgres.health

      assert_equal('OK', health[:status])
      assert_equal(5, health[:pool][:waiting])
    end

    def test_health_includes_pool
      config['/postgres/dsn'] = 'postgres://example.invalid/dummy'
      stub_instance(FakePool.new(max: 10, size: 2, waiting: 0))
      health = Postgres.health

      assert_equal('OK', health[:status])
      assert_equal({max: 10, allocated: 2, waiting: 0}, health[:pool])
    end

    # 既存インスタンスが無い (ブート時 DSN 無し) 場合は切断をスキップして繋ぎ直す。
    def test_reconnect_without_existing_instance_is_safe
      config['/postgres/dsn'] = nil
      Singleton.__init__(Postgres)

      assert_nil(Postgres.reconnect)
      assert_false(Postgres.connected?)
    end
  end
end
