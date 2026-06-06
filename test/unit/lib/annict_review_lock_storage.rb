require 'securerandom'

module Mulukhiya
  class AnnictReviewLockStorageTest < TestCase
    def disable?
      return true unless Redis.health[:status] == 'OK'
      return super
    end

    def setup
      return if disable?
      @storage = AnnictReviewLockStorage.new
      @account_id = "test_#{SecureRandom.hex(8)}"
      @work_id = SecureRandom.random_number(1_000_000)
      @token = nil
    end

    def teardown
      return if disable?
      @storage.release(@account_id, @work_id, @token)
    end

    def test_prefix
      assert_equal('annict_review_lock', @storage.prefix)
    end

    def test_ttl
      assert_kind_of(Integer, @storage.ttl)
      assert_operator(@storage.ttl, :>, 0)
    end

    def test_acquire_first_then_blocks_duplicate
      return if disable?

      @token = @storage.acquire(@account_id, @work_id)

      assert(@token)
      assert_nil(@storage.acquire(@account_id, @work_id))
    end

    def test_release_allows_reacquire
      return if disable?

      @token = @storage.acquire(@account_id, @work_id)
      @storage.release(@account_id, @work_id, @token)
      @token = @storage.acquire(@account_id, @work_id)

      assert(@token)
    end

    def test_distinct_work_is_independent
      return if disable?
      other_work = @work_id + 1
      other_token = nil

      @token = @storage.acquire(@account_id, @work_id)
      other_token = @storage.acquire(@account_id, other_work)

      assert(@token)
      assert(other_token)
    ensure
      @storage&.release(@account_id, other_work, other_token) unless disable?
    end

    def test_release_with_wrong_token_keeps_lock
      return if disable?

      @token = @storage.acquire(@account_id, @work_id)
      @storage.release(@account_id, @work_id, 'someone-elses-token')

      assert(@token)
      assert_nil(@storage.acquire(@account_id, @work_id))
    end

    def test_release_with_nil_token_is_noop
      return if disable?

      @token = @storage.acquire(@account_id, @work_id)
      @storage.release(@account_id, @work_id, nil)

      assert_nil(@storage.acquire(@account_id, @work_id))
    end

    def test_alert_threshold_default
      assert_kind_of(Integer, @storage.alert_threshold)
      assert_operator(@storage.alert_threshold, :>, 0)
    end

    def test_record_conflict_returns_true_only_when_threshold_reached
      return if disable?
      original = config['/service/annict/review/idempotency/alert_threshold']
      config['/service/annict/review/idempotency/alert_threshold'] = 3
      @storage.instance_variable_set(:@alert_threshold, nil)

      assert_false(@storage.record_conflict(@account_id, @work_id))
      assert_false(@storage.record_conflict(@account_id, @work_id))
      assert_true(@storage.record_conflict(@account_id, @work_id))
      assert_false(@storage.record_conflict(@account_id, @work_id))
    ensure
      config['/service/annict/review/idempotency/alert_threshold'] = original
      @storage.instance_variable_set(:@alert_threshold, nil)
    end

    def test_record_conflict_counts_per_account
      return if disable?
      original = config['/service/annict/review/idempotency/alert_threshold']
      config['/service/annict/review/idempotency/alert_threshold'] = 2
      @storage.instance_variable_set(:@alert_threshold, nil)
      other_account = "test_#{SecureRandom.hex(8)}"

      assert_false(@storage.record_conflict(@account_id, @work_id))
      assert_false(@storage.record_conflict(other_account, @work_id))
      assert_true(@storage.record_conflict(@account_id, @work_id))
    ensure
      config['/service/annict/review/idempotency/alert_threshold'] = original
      @storage.instance_variable_set(:@alert_threshold, nil)
    end
  end
end
