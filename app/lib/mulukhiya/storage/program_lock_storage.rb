require 'securerandom'

module Mulukhiya
  # 番組表の書き込み直列化ロック (#4534)。
  #
  # `Program` の編集 4 メソッド（add_entry / update_entry / delete_entry /
  # increment_episode）はいずれも「Redis から全体を読む → 破壊的に変更する →
  # 全体を書き戻す」形で、排他が無いと lost update が起こる。特に痛いのは
  # 「増分と別編集の交差」で、片方の save が削除したエントリを復活させ、
  # トグルを巻き戻す。両方の HTTP は 200 を返すので気づけない。
  #
  # ⚠ さらに交差すると YAML と Redis キャッシュの内容がズレ、以降の read は
  # Redis の旧スナップショットを返し続けるため、単発の lost update が
  # **恒久的なロールバック**になる。
  #
  # ComposeTemplateLockStorage (#4457 / #4460) と同型だが、番組表は
  # per-account でなくインスタンスに 1 つなので key も 1 つ。保持中の競合は
  # 409 (ConflictError) で即返し、クライアントに再取得 → 再試行させる
  # （番組表の編集は低頻度なのでキューイングしない）。Redis 障害時はロックを
  # 諦めて実行を阻害しない (fail-open)。
  class ProgramLockStorage < Redis
    # TTL 切れで自然解放後に別リクエストが同一 key を acquire したケースで、遅延
    # release が他者の新ロックを消さないよう compare-and-delete する。
    RELEASE_SCRIPT = <<~LUA.freeze
      if redis.call('GET', KEYS[1]) == ARGV[1] then
        return redis.call('DEL', KEYS[1])
      else
        return 0
      end
    LUA

    # ロック保持の TTL 秒。⚠ 「処理時間の見積り」ではなく「Ruby 側がストール
    # してもロックを失わない余裕」で決める。RMW の途中に TTL が切れると、
    # ロック無しで書き込む別リクエストが現れて lost update が黙って復活する。
    #
    # ⚠ **ロックを持っている区間にネットワーク I/O を入れないこと。**
    # increment_episode の Annict 呼び出し（open / read で各 5 秒 × 最大 3 回 +
    # リトライ待ち）は素でこの TTL を超えうる。超えると別の編集がロックを獲得でき、
    # そこへ元のリクエストが書き戻して lost update が復活する（PR #4569 の Codex P2）。
    # 現状 Annict はロックの外で先に解決してあるので、区間は Redis と YAML の
    # 書き込みだけ。他のロック（既定 30 秒）と水準を揃える。
    #
    # 定数にして config ルックアップを持たない（存在しないパスは ConfigError を
    # raise し、acquire の rescue に飲まれてロックが黙って無効化される footgun を
    # 避けるため。rescue は Redis 障害のみを対象に保つ）。
    LOCK_TTL_SECONDS = 30

    # 番組表の書き込みを直列化して block を実行する。保持中は ConflictError(409)。
    def synchronize
      token = acquire
      begin
        return yield
      ensure
        release(token) if token
      end
    end

    def ttl
      return LOCK_TTL_SECONDS
    end

    private

    # SET key value NX EX ttl で原子的に獲得。獲得できれば token を返す。
    # 他者保有中は ConflictError。Redis 障害時は fail-open で nil を返す
    # （nil の間はロック無しで実行され、release も走らない）。
    def acquire
      key = create_key(lock_key)
      token = SecureRandom.uuid
      return token if redis.call('SET', key, token, 'NX', 'EX', ttl) == 'OK'
      raise Ginseng::ConflictError, '別の更新が進行中です。少し待って再試行してください。'
    rescue Ginseng::ConflictError
      raise
    rescue => e
      e.log
      return nil
    end

    def release(token)
      redis.call('EVAL', RELEASE_SCRIPT, 1, create_key(lock_key), token)
    rescue => e
      e.log
    end

    def lock_key
      return 'program_lock'
    end
  end
end
