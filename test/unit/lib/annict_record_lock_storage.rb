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
    end

    def teardown
      return if disable?
      @storage.release(@account_id, @episode_id)
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

      assert(@storage.acquire(@account_id, @episode_id))
      assert_false(@storage.acquire(@account_id, @episode_id))
    end

    def test_release_allows_reacquire
      return if disable?

      assert(@storage.acquire(@account_id, @episode_id))
      @storage.release(@account_id, @episode_id)

      assert(@storage.acquire(@account_id, @episode_id))
    end

    def test_distinct_episode_is_independent
      return if disable?
      other_episode = @episode_id + 1

      assert(@storage.acquire(@account_id, @episode_id))
      assert(@storage.acquire(@account_id, other_episode))
    ensure
      @storage&.release(@account_id, other_episode) unless disable?
    end
  end
end
