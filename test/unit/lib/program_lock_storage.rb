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
      assert_raise(Ginseng::ConflictError) {@storage.send(:acquire)}
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

    # 遅れて届いた release が、TTL 切れ後に他者が取り直したロックを消さないこと
    # （compare-and-delete）。
    def test_release_does_not_delete_others_lock
      return if disable?
      stale = @storage.send(:acquire)
      @storage.send(:release, stale)
      @token = @storage.send(:acquire)
      @storage.send(:release, stale)

      assert_raise(Ginseng::ConflictError) {@storage.send(:acquire)}
    end
  end
end
