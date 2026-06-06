require 'securerandom'

module Mulukhiya
  # AnnictRecordLockStorage の review 版。同一 (account, work_id) への createReview
  # 重複を TTL 窓で抑止する (#4342)。挙動は record 版と同一。
  class AnnictReviewLockStorage < Redis
    RELEASE_SCRIPT = <<~LUA.freeze
      if redis.call('GET', KEYS[1]) == ARGV[1] then
        return redis.call('DEL', KEYS[1])
      else
        return 0
      end
    LUA

    def acquire(account_id, work_id)
      key = create_key(lock_key(account_id, work_id))
      token = SecureRandom.uuid
      return token if redis.call('SET', key, token, 'NX', 'EX', ttl) == 'OK'
      return nil
    rescue => e
      e.log(account_id:, work_id:)
      # Redis 障害時は冪等性を諦め、本来の review 投稿を阻害しない (fail-open)。
      return SecureRandom.uuid
    end

    def release(account_id, work_id, token)
      return unless token
      key = create_key(lock_key(account_id, work_id))
      redis.call('EVAL', RELEASE_SCRIPT, 1, key, token)
    rescue => e
      e.log(account_id:, work_id:)
    end

    def record_conflict(account_id, work_id)
      key = create_key(conflict_key(account_id))
      count = redis.call('INCR', key).to_i
      redis.call('EXPIRE', key, conflict_window) if count == 1
      return count == alert_threshold
    rescue => e
      e.log(account_id:, work_id:)
      return false
    end

    def ttl
      return @ttl ||= config['/service/annict/review/idempotency/ttl'] || 30
    end

    def alert_threshold
      return @alert_threshold ||= config['/service/annict/review/idempotency/alert_threshold'] || 10
    end

    def prefix
      return 'annict_review_lock'
    end

    private

    def lock_key(account_id, work_id)
      return [account_id, work_id].join(':')
    end

    def conflict_key(account_id)
      return ['conflict', account_id, Time.now.to_i / conflict_window].join(':')
    end

    def conflict_window
      return 60
    end
  end
end
