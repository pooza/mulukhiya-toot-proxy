module Mulukhiya
  class ProgramLockStorageTest < TestCase
    def disable?
      return true unless Redis.health[:status] == 'OK'
      return super
    end

    def setup
      return if disable?
      @storage = ProgramLockStorage.new
      @token = nil
    end

    def teardown
      return if disable?
      @storage.send(:release, @token) if @token
    end

    def test_ttl
      return if disable?

      assert_kind_of(Integer, @storage.ttl)
      assert_operator(@storage.ttl, :>, 0)
    end

    # ⚠ 「実際にブロックする」正テスト。fail-open の rescue が効きすぎて（config
    # ルックアップの ConfigError 等を飲んで）ロックが黙って無効化されるのは、
    # 書けてしまう側からは気づけない。ここが唯一の検出点になる。
    def test_acquire_blocks_duplicate
      return if disable?

      @token = @storage.send(:acquire)

      assert(@token)
      error = assert_raise(ConflictError) {@storage.send(:acquire)}

      # 待てば通る 409 なので、理由と待ち時間をクライアントへ渡す (#4579)。
      assert_equal(:locked, error.code)
      assert_equal(ProgramLockStorage::LOCK_TTL_SECONDS, error.retry_after)
    end

    # ⚠ `Retry-After` は TTL 全体でなく残り時間 (#4763)。終わり近くのロックで
    # クライアントを 30 秒待たせない。⚠ 0 秒にはしない（切り上げ）。
    def test_retry_after_is_remaining_time
      return if disable?

      @token = @storage.send(:acquire)
      @storage.redis.call('PEXPIRE', @storage.create_key(@storage.send(:lock_key)), 4200)
      error = assert_raise(ConflictError) {@storage.send(:acquire)}

      assert_equal(5, error.retry_after)
    end

    def test_release_allows_reacquire
      return if disable?

      @token = @storage.send(:acquire)
      @storage.send(:release, @token)
      @token = @storage.send(:acquire)

      assert(@token)
    end

    # 例外で抜けてもロックを持ち逃げしない（持ち逃げすると TTL の 30 秒間、
    # 番組表の編集が全部 409 になる）。
    def test_synchronize_releases_on_error
      return if disable?

      assert_raise(RuntimeError) {@storage.synchronize {raise 'boom'}}
      @token = @storage.send(:acquire)

      assert(@token)
    end

    # ⚠⚠ **fail-open したことが観測できること (#4577 の 2)。**従来は `e.log` 止まりで
    # Sentry に届かず、ロックが黙って無効化されたことを知る手段が無かった。
    #
    # ⚠ [LockDegradationTest](lock_degradation.rb) は mixin 単体しか見ていないので、
    # **実クラスからの呼び出しを外しても向こうは緑のまま**になる。ここが call site の
    # 検出点（#4578 で踏んだ「検査していないのに緑」と同じ型）。
    def test_acquire_escalates_when_redis_is_unreachable
      return if disable?
      recorded = []
      @storage.define_singleton_method(:redis) {raise Ginseng::Redis::Error, 'boom'}
      @storage.define_singleton_method(:escalate) {|_error, state, _values| recorded.push(state)}

      assert_nil(@storage.send(:acquire), 'fail-open しているのに token を返している')
      assert_equal(['fail-open'], recorded)
    end

    # ⚠⚠ **`EVAL` だけ通らない構成（ACL / scripting 制限）を見る。**acquire は成功して
    # release だけが毎回失敗するので、**すべての書き込みが TTL の 30 秒ぶんロックを
    # 持ち逃げ**し、エディタが延々 409 を返す。fail-open より静かで痛い。
    def test_release_escalates_when_eval_fails
      return if disable?
      recorded = []
      @storage.define_singleton_method(:redis) {raise Ginseng::Redis::Error, 'boom'}
      @storage.define_singleton_method(:escalate) {|_error, state, _values| recorded.push(state)}

      @storage.send(:release, 'token')

      assert_equal(['release-failed'], recorded)
    end

    # 遅れて届いた release が、TTL 切れ後に他者が取り直したロックを消さないこと
    # （compare-and-delete）。
    def test_release_does_not_delete_others_lock
      return if disable?
      stale = @storage.send(:acquire)
      @storage.send(:release, stale)
      @token = @storage.send(:acquire)
      @storage.send(:release, stale)

      assert_raise(ConflictError) {@storage.send(:acquire)}
    end
  end
end
