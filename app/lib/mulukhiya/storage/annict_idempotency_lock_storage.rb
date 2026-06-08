require 'securerandom'

module Mulukhiya
  # Annict の record/review 冪等性ロックの共通基底。同一 (account, target) への
  # createRecord / createReview 重複を TTL 窓で抑止する。compare-and-delete 解放・
  # 衝突回数の minute_bucket 集計・しきい値到達検知・Redis 障害時の fail-open を
  # 実装し、サブクラスは prefix / config_key / id_label を与えるだけ
  # (#4330 / #4342 / #4345 / #4346)。
  class AnnictIdempotencyLockStorage < Redis
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
    # network blip リトライによる同一 (account, target) への重複投稿を TTL 窓で
    # 抑止する (#4330)。
    def acquire(account_id, target_id)
      key = create_key(lock_key(account_id, target_id))
      token = SecureRandom.uuid
      return token if redis.call('SET', key, token, 'NX', 'EX', ttl) == 'OK'
      return nil
    rescue => e
      e.log(account_id:, id_label => target_id)
      # Redis 障害時は冪等性を諦め、本来の投稿を阻害しない (fail-open)。戻り値の
      # token を持ったまま release が呼ばれても、Redis 側にエントリはないため
      # compare-and-delete は no-op で害がない。
      return SecureRandom.uuid
    end

    # 投稿失敗時に呼び、リトライを即座に許可する。成功時は解放せず TTL 切れまで
    # ロックを残し、短時間の重複投稿を抑止する。token は acquire の戻り値
    # （一致した時だけ DEL される）。
    def release(account_id, target_id, token)
      return unless token
      key = create_key(lock_key(account_id, target_id))
      redis.call('EVAL', RELEASE_SCRIPT, 1, key, token)
    rescue => e
      e.log(account_id:, id_label => target_id)
    end

    # 直近 1 分間の冪等性ロック衝突回数をアカウント単位で計上し、しきい値
    # (alert_threshold) に到達した瞬間だけ true を返す。capsicum 等が同一 target
    # へリトライループに陥った異常を Sentry alert に昇格する判定に使う (#4346)。
    # bucket は `Time.now.to_i / 60` の minute_bucket。発火後の同一 bucket では
    # false を返し続け、bucket 切替時にリセットされる。Redis 障害時は fail-open。
    def record_conflict(account_id, target_id)
      key = create_key(conflict_key(account_id))
      count = redis.call('INCR', key).to_i
      redis.call('EXPIRE', key, conflict_window) if count == 1
      return count == alert_threshold
    rescue => e
      e.log(account_id:, id_label => target_id)
      return false
    end

    def ttl
      return @ttl ||= config[config_path('ttl')] || 30
    end

    def alert_threshold
      return @alert_threshold ||= config[config_path('alert_threshold')] || 10
    end

    private

    def config_path(suffix)
      return "/service/annict/#{config_key}/idempotency/#{suffix}"
    end

    # config パスの名前空間 ('record' / 'review')。
    def config_key
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    # ログに添える target の意味ラベル (:episode_id / :work_id)。
    def id_label
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def lock_key(account_id, target_id)
      return [account_id, target_id].join(':')
    end

    def conflict_key(account_id)
      return ['conflict', account_id, Time.now.to_i / conflict_window].join(':')
    end

    def conflict_window
      return 60
    end
  end
end
