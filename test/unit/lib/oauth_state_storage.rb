module Mulukhiya
  # 「state が無い」と「取り出しに失敗した」を分ける (#4724)。
  #
  # ⚠⚠ 従来は Redis の失敗も nil に潰していたので、呼び出し側からは「無効な
  # state」にしか見えず、**Redis 障害中の OAuth 認可が 403 に化けて**
  # Sentry にも出なかった（403 は `report_error` で log 止め）。
  class OAuthStateStorageTest < TestCase
    def disable?
      return true unless Redis.health[:status] == 'OK'
      return super
    end

    def setup
      return if disable?
      @storage = OAuthStateStorage.new
    end

    def test_consume_returns_nil_when_absent
      return if disable?

      assert_nil(@storage.consume(OAuthHelper.generate_state))
    end

    def test_consume_returns_values_once
      return if disable?
      state = OAuthHelper.generate_state
      @storage.set(state, {service: 'spotify', account_id: 1})

      assert_equal({service: 'spotify', account_id: 1}, @storage.consume(state))
      assert_nil(@storage.consume(state))
    end

    # 🔴 Redis の失敗は nil にしない。上げて、呼び出し側の `report_error` に
    # サーバー側の失敗（500）として扱わせる。
    def test_consume_raises_when_redis_fails
      return if disable?
      broken = Object.new
      broken.define_singleton_method(:call) {|*| raise RedisClient::CannotConnectError, 'boom'}
      @storage.define_singleton_method(:redis) {broken}

      assert_raise(RedisClient::CannotConnectError) {@storage.consume('state')}
    end

    # ⚠ 壊れた値も「無い」ではない。GETDEL で既に消えているので、黙ると
    # 原因が追えない。
    def test_consume_raises_when_entry_is_broken
      return if disable?
      state = OAuthHelper.generate_state
      @storage.redis.call('SET', @storage.create_key(state), '{broken')

      assert_raise(JSON::ParserError) {@storage.consume(state)}
    end
  end
end
