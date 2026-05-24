require 'securerandom'

module Mulukhiya
  class AnnictRecordLockStorageTest < TestCase
    def disable?
      return true unless Redis.health[:status] == 'OK'
      return super
    end

    def setup
      return if disable?
      @storage = AnnictRecordLockStorage.new
      @account_id = "test_#{SecureRandom.hex(8)}"
      @episode_id = SecureRandom.random_number(1_000_000)
      @token = nil
    end

    def teardown
      return if disable?
      @storage.release(@account_id, @episode_id, @token)
    end

    def test_prefix
      assert_equal('annict_record_lock', @storage.prefix)
    end

    def test_ttl
      assert_kind_of(Integer, @storage.ttl)
      assert_operator(@storage.ttl, :>, 0)
    end

    def test_acquire_first_then_blocks_duplicate
      return if disable?

      @token = @storage.acquire(@account_id, @episode_id)

      assert(@token)
      assert_nil(@storage.acquire(@account_id, @episode_id))
    end

    def test_release_allows_reacquire
      return if disable?

      @token = @storage.acquire(@account_id, @episode_id)
      @storage.release(@account_id, @episode_id, @token)
      @token = @storage.acquire(@account_id, @episode_id)

      assert(@token)
    end

    def test_distinct_episode_is_independent
      return if disable?
      other_episode = @episode_id + 1
      other_token = nil

      @token = @storage.acquire(@account_id, @episode_id)
      other_token = @storage.acquire(@account_id, other_episode)

      assert(@token)
      assert(other_token)
    ensure
      @storage&.release(@account_id, other_episode, other_token) unless disable?
    end

    # TTL 跨ぎで A の旧 token による release が B の新ロックを消さないこと。
    # 直接 TTL を待たず、compare-and-delete の対称性で検証する (#4345)。
    def test_release_with_wrong_token_keeps_lock
      return if disable?

      @token = @storage.acquire(@account_id, @episode_id)
      @storage.release(@account_id, @episode_id, 'someone-elses-token')

      assert(@token)
      assert_nil(@storage.acquire(@account_id, @episode_id))
    end

    def test_release_with_nil_token_is_noop
      return if disable?

      @token = @storage.acquire(@account_id, @episode_id)
      @storage.release(@account_id, @episode_id, nil)

      assert_nil(@storage.acquire(@account_id, @episode_id))
    end
  end
end
