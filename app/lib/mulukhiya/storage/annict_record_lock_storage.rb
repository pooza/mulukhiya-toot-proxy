module Mulukhiya
  class AnnictRecordLockStorage < Redis
    # SET key value NX EX ttl で原子的にロックを獲得する。獲得できれば true。
    # capsicum 等の network blip リトライによる同一 (account, episode) への
    # 重複 createRecord を TTL 窓で抑止する (#4330)。
    def acquire(account_id, episode_id)
      key = create_key(lock_key(account_id, episode_id))
      return redis.call('SET', key, Time.now.to_i.to_s, 'NX', 'EX', ttl) == 'OK'
    rescue => e
      e.log(account_id:, episode_id:)
      # Redis 障害時は冪等性を諦め、本来の record 投稿を阻害しない (fail-open)。
      return true
    end

    # createRecord 失敗時に呼び、リトライを即座に許可する。成功時は解放せず
    # TTL 切れまでロックを残し、短時間の重複投稿を抑止する。
    def release(account_id, episode_id)
      unlink(lock_key(account_id, episode_id))
    rescue => e
      e.log(account_id:, episode_id:)
    end

    def ttl
      return @ttl ||= (config['/service/annict/record/idempotency/ttl'] || 30)
    end

    def prefix
      return 'annict_record_lock'
    end

    private

    def lock_key(account_id, episode_id)
      return [account_id, episode_id].join(':')
    end
  end
end
