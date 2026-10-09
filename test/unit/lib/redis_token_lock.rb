module Mulukhiya
  # トークン付きロックの取得・解放が、切れた接続を 1 回だけ撃ち直す (#4742)。
  #
  # 🔴 Redis の再起動後、プールに残った接続で撃った最初のコマンドは必ず `ConnectionError` に
  # なる。ロックはそこで fail-open し、同じ要求の読み書きは ginseng-redis の再送で通るので、
  # 利用者には正常な 200 のままロックだけが外れていた。
  class RedisTokenLockTest < TestCase
    # `redis.call` の差し替え。`failures` の数だけ先頭の呼び出しを落とす。
    class ClientDouble
      attr_reader :calls

      def initialize(errors: [], store: {}, applied_before_error: false)
        @errors = errors.dup
        @store = store
        @applied_before_error = applied_before_error
        @calls = []
      end

      def call(*command)
        @calls.push(command.first)
        if error = @errors.shift
          apply(command) if @applied_before_error
          raise error
        end
        return apply(command)
      end

      private

      def apply(command)
        name, key, value = command
        case name
        when 'SET'
          return nil if @store.key?(key)
          @store[key] = value
          return 'OK'
        when 'GET'
          return @store[key]
        when 'EVAL'
          key, value = command.last(2)
          return 0 unless @store[key] == value
          @store.delete(key)
          return 1
        end
      end
    end

    def storage_with(client)
      storage = Redis.allocate
      storage.define_singleton_method(:redis) {client}
      return storage
    end

    def test_acquire_retries_once_on_dead_connection
      client = ClientDouble.new(errors: [RedisClient::ConnectionError.new('Broken pipe')])
      storage = storage_with(client)

      assert(storage.acquire_token('k', 'token', 30))
      assert_equal(['SET', 'SET'], client.calls)
    end

    # ⚠ 2 回目も落ちたら上げる（呼び出し側の fail-open に任せる）。待たない・粘らない。
    def test_acquire_gives_up_after_second_failure
      errors = Array.new(2) {RedisClient::CannotConnectError.new('Connection refused')}
      client = ClientDouble.new(errors:)
      storage = storage_with(client)

      assert_raise(RedisClient::CannotConnectError) {storage.acquire_token('k', 'token', 30)}
      assert_equal(['SET', 'SET'], client.calls)
    end

    # ⚠ タイムアウトは撃ち直さない（詰まっている相手に待ちを 2 倍にするだけ）。
    def test_acquire_does_not_retry_timeout
      client = ClientDouble.new(errors: [RedisClient::ReadTimeoutError.new('Waited 1 seconds')])
      storage = storage_with(client)

      assert_raise(RedisClient::ReadTimeoutError) {storage.acquire_token('k', 'token', 30)}
      assert_equal(['SET'], client.calls)
    end

    # 🔴 1 回目が届いたあとで応答だけ落ちた場合、撃ち直しは NX に負ける。
    # 鍵は自分のものなので「他者が保持中」と答えない。
    def test_acquire_recognizes_own_token_after_lost_reply
      client = ClientDouble.new(
        errors: [RedisClient::ConnectionError.new('Connection reset')],
        applied_before_error: true,
      )
      storage = storage_with(client)

      assert(storage.acquire_token('k', 'token', 30))
      assert_equal(['SET', 'SET', 'GET'], client.calls)
    end

    # ⚠ 撃ち直しで負けた相手が本当に他者なら、取れていない。
    def test_acquire_loses_to_other_holder_after_retry
      client = ClientDouble.new(
        errors: [RedisClient::ConnectionError.new('Broken pipe')],
        store: {'k' => 'other'},
      )
      storage = storage_with(client)

      assert_false(storage.acquire_token('k', 'token', 30))
    end

    # ⚠ 撃ち直していないときは GET を足さない（平常時のコマンド数を増やさない）。
    def test_acquire_without_error_issues_single_command
      client = ClientDouble.new(store: {'k' => 'other'})
      storage = storage_with(client)

      assert_false(storage.acquire_token('k', 'token', 30))
      assert_equal(['SET'], client.calls)
    end

    def test_release_retries_once_on_dead_connection
      client = ClientDouble.new(
        errors: [RedisClient::ConnectionError.new('Broken pipe')],
        store: {'k' => 'token'},
      )
      storage = storage_with(client)

      assert(storage.release_token('k', 'token'))
      assert_equal(['EVAL', 'EVAL'], client.calls)
    end

    def test_release_keeps_other_holders_lock
      client = ClientDouble.new(store: {'k' => 'other'})
      storage = storage_with(client)

      assert_false(storage.release_token('k', 'token'))
    end

    # 番組表のロックがこの口を通っていること（呼び出しを直叩きへ戻すと落ちる）。
    def test_program_lock_survives_dead_connection
      client = ClientDouble.new(errors: [RedisClient::ConnectionError.new('Broken pipe')])
      storage = ProgramLockStorage.allocate
      storage.define_singleton_method(:redis) {client}
      fail_open = false
      storage.define_singleton_method(:note_fail_open) {|*| fail_open = true}

      assert_equal(:done, storage.synchronize {:done})
      assert_false(fail_open)
      assert_equal(['SET', 'SET', 'EVAL'], client.calls)
    end
  end
end
