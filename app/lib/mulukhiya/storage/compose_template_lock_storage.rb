require 'securerandom'

module Mulukhiya
  # 投稿テンプレート CRUD の per-account 書き込み直列化ロック (#4457, #4460)。
  # 保存は user_config への read-modify-write（`all` → 配列編集 → `persist`）で
  # 非原子的なため、多端末同時書き込みで lost update が起こりうる（Codex P2）。
  # account 単位でロックを取り、保持中の競合は 409 (ConflictError) で即返して
  # クライアントに再取得 → 再試行させる（テンプレ CRUD は低頻度なのでキューイング
  # しない）。Redis 障害時はロックを諦めて実行を阻害しない (fail-open)。
  class ComposeTemplateLockStorage < Redis
    # TTL 切れで自然解放後に別リクエストが同一 key を acquire したケースで、遅延
    # release が他者の新ロックを消さないよう compare-and-delete する。
    RELEASE_SCRIPT = <<~LUA.freeze
      if redis.call('GET', KEYS[1]) == ARGV[1] then
        return redis.call('DEL', KEYS[1])
      else
        return 0
      end
    LUA

    # ロック保持の TTL 秒。テンプレ CRUD 自体は一瞬で終わるが、TTL は「処理時間の
    # 見積り」ではなく「Ruby 側がストールしてもロックを失わない余裕」で決める。
    # GC・Redis の応答遅延で RMW の途中に TTL が切れると、ロック無しで書き込む
    # 別リクエストが現れて lost update が黙って復活するため（確率は低いが検知も
    # できない）。CRUD は低頻度で、プロセスが死んでロックが残っても待たされるのは
    # 当人だけなので、Annict 系ロック（既定 30 秒）と同水準に揃える (#4461)。
    #
    # 定数にして config ルックアップを持たない（存在しないパスは ConfigError を
    # raise し、acquire の rescue に飲まれてロックが黙って無効化される footgun を
    # 避けるため。rescue は Redis 障害のみを対象に保つ）。
    LOCK_TTL_SECONDS = 30

    # account 単位で block を直列化して実行する。保持中は ConflictError(409)。
    def synchronize(account_id)
      token = acquire(account_id)
      begin
        return yield
      ensure
        release(account_id, token) if token
      end
    end

    def ttl
      return LOCK_TTL_SECONDS
    end

    private

    # SET key value NX EX ttl で原子的に獲得。獲得できれば token を返す。
    # 他者保有中は ConflictError。Redis 障害時は fail-open で nil を返す
    # （nil の間はロック無しで実行され、release も走らない）。
    def acquire(account_id)
      key = create_key(lock_key(account_id))
      token = SecureRandom.uuid
      return token if redis.call('SET', key, token, 'NX', 'EX', ttl) == 'OK'
      raise Ginseng::ConflictError, '別の更新が進行中です。少し待って再試行してください。'
    rescue Ginseng::ConflictError
      raise
    rescue => e
      e.log(account_id:)
      return nil
    end

    def release(account_id, token)
      redis.call('EVAL', RELEASE_SCRIPT, 1, create_key(lock_key(account_id)), token)
    rescue => e
      e.log(account_id:)
    end

    def lock_key(account_id)
      return ['compose_template_lock', account_id].join(':')
    end
  end
end
