require 'securerandom'

module Mulukhiya
  class AnnictRecordLockStorage < Redis
    # release で誤って他人のロックを削除しないため compare-and-delete する。
    # TTL 切れで A の自然解放後に B が同一 key で acquire したケースで、A の遅延
    # rescue が呼ぶ release が B の新ロックを消さないようにする (#4345)。
    RELEASE_SCRIPT = <<~LUA.freeze
      if redis.call('GET', KEYS[1]) == ARGV[1] then
        return redis.call('DEL', KEYS[1])
      else
        return 0
      end
    LUA

    # SET key value NX EX ttl で原子的にロックを獲得する。獲得できれば token を
    # 返す（nil なら他者保有または Redis 障害を伴う失敗）。capsicum 等の
    # network blip リトライによる同一 (account, episode) への重複 createRecord を
    # TTL 窓で抑止する (#4330)。
    def acquire(account_id, episode_id)
      key = create_key(lock_key(account_id, episode_id))
      token = SecureRandom.uuid
      return token if redis.call('SET', key, token, 'NX', 'EX', ttl) == 'OK'
      return nil
    rescue => e
      e.log(account_id:, episode_id:)
      # Redis 障害時は冪等性を諦め、本来の record 投稿を阻害しない (fail-open)。
      # 戻り値の token を持ったまま release が呼ばれても、Redis 側にエントリは
      # ないため compare-and-delete は no-op で害がない。
      return SecureRandom.uuid
    end

    # createRecord 失敗時に呼び、リトライを即座に許可する。成功時は解放せず
    # TTL 切れまでロックを残し、短時間の重複投稿を抑止する。token は acquire
    # の戻り値（一致した時だけ DEL される）。
    def release(account_id, episode_id, token)
      return unless token
      key = create_key(lock_key(account_id, episode_id))
      redis.call('EVAL', RELEASE_SCRIPT, 1, key, token)
    rescue => e
      e.log(account_id:, episode_id:)
    end

    def ttl
      return @ttl ||= config['/service/annict/record/idempotency/ttl'] || 30
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
