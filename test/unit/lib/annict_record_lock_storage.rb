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

    def test_alert_threshold_default
      assert_kind_of(Integer, @storage.alert_threshold)
      assert_operator(@storage.alert_threshold, :>, 0)
    end

    def test_record_conflict_below_threshold_returns_false
      return if disable?
      original = config['/service/annict/record/idempotency/alert_threshold']
      config['/service/annict/record/idempotency/alert_threshold'] = 3
      @storage.instance_variable_set(:@alert_threshold, nil)

      assert_false(@storage.record_conflict(@account_id, @episode_id))
      assert_false(@storage.record_conflict(@account_id, @episode_id))
    ensure
      config['/service/annict/record/idempotency/alert_threshold'] = original
      @storage.instance_variable_set(:@alert_threshold, nil)
    end

    def test_record_conflict_returns_true_only_when_threshold_reached
      return if disable?
      original = config['/service/annict/record/idempotency/alert_threshold']
      config['/service/annict/record/idempotency/alert_threshold'] = 3
      @storage.instance_variable_set(:@alert_threshold, nil)

      # 1, 2 件目は false、3 件目で true、それ以降は同一 bucket では false
      assert_false(@storage.record_conflict(@account_id, @episode_id))
      assert_false(@storage.record_conflict(@account_id, @episode_id))
      assert_true(@storage.record_conflict(@account_id, @episode_id))
      assert_false(@storage.record_conflict(@account_id, @episode_id))
    ensure
      config['/service/annict/record/idempotency/alert_threshold'] = original
      @storage.instance_variable_set(:@alert_threshold, nil)
    end

    def test_record_conflict_counts_per_account
      return if disable?
      original = config['/service/annict/record/idempotency/alert_threshold']
      config['/service/annict/record/idempotency/alert_threshold'] = 2
      @storage.instance_variable_set(:@alert_threshold, nil)
      other_account = "test_#{SecureRandom.hex(8)}"

      # 別アカウントは別カウンタなので干渉しない
      assert_false(@storage.record_conflict(@account_id, @episode_id))
      assert_false(@storage.record_conflict(other_account, @episode_id))
      assert_true(@storage.record_conflict(@account_id, @episode_id))
    ensure
      config['/service/annict/record/idempotency/alert_threshold'] = original
      @storage.instance_variable_set(:@alert_threshold, nil)
    end
  end
end
