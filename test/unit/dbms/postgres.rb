module Mulukhiya
  class PostgresTest < TestCase
    class FakeConnection
      attr_reader :disconnected

      def disconnect
        @disconnected = true
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

    # 既存インスタンスが無い (ブート時 DSN 無し) 場合は切断をスキップして繋ぎ直す。
    def test_reconnect_without_existing_instance_is_safe
      config['/postgres/dsn'] = nil
      Singleton.__init__(Postgres)

      assert_nil(Postgres.reconnect)
      assert_false(Postgres.connected?)
    end
  end
end
