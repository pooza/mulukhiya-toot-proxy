module Mulukhiya
  class Redis < Ginseng::Redis::Service
    include Package

    # TTL 切れで自然解放されたあと、別の要求が同じ鍵を取ったケースで、遅れてきた
    # release が他者の新しいロックを消さないよう compare-and-delete する (#4345)。
    RELEASE_TOKEN_SCRIPT = <<~LUA.freeze
      if redis.call('GET', KEYS[1]) == ARGV[1] then
        return redis.call('DEL', KEYS[1])
      else
        return 0
      end
    LUA

    def initialize(params = {})
      unless params[:url]
        dsn = Redis.dsn
        dsn.db ||= 1
        raise Ginseng::Redis::Error, "Invalid DSN '#{dsn}'" unless dsn.absolute?
        raise Ginseng::Redis::Error, "Invalid scheme '#{dsn.scheme}'" unless dsn.scheme == 'redis'
        params[:url] = dsn.to_s
      end
      super
    end

    def underscore
      return self.class.to_s.split('::').last.sub(/Storage$/, '').underscore
    end

    def log(message)
      logger.info({storage: underscore}.merge(message))
    end

    # 鍵の残り寿命を秒で返す（切り上げ・最低 1）。取れないときは `fallback` (#4763)。
    #
    # ⚠ ロック競合の 409 の `Retry-After` に使う。TTL 全体を返すと、先行の書き込みが
    # 終わり近くでもクライアントを最大 TTL ぶん待たせる。⚠ **0 秒にはしない**
    # （切り捨てると「今すぐ再送してよい」になり、まだ解けていない鍵へ撃ち直す）。
    # ⚠ `key` は `create_key` 済みのものを渡す。
    def remaining_seconds(key, fallback)
      milliseconds = redis.call('PTTL', key).to_i
      return fallback unless milliseconds.positive?
      return [(milliseconds / 1000.0).ceil, 1].max
    rescue
      return fallback
    end

    # 既に値があれば書き換えない SET (#4575)。獲得できたとき true。
    #
    # ⚠ **キャッシュを「温める」読み経路はこちらを使うこと。**素の SET だと、
    # 古い内容を読んだ読み手が、その後に完走した書き手の新しい値を上書きできる。
    # 番組表のように読みがロックの外にある構造では、それが恒久的なロールバックに
    # なる（読みはキャッシュを優先するので、以後ずっと旧データが返る）。
    # ⚠ Naming/PredicateMethod を inline disable する。真偽値を返すが、これは
    # 述語ではなく「獲得できたか」を返す副作用付きコマンド。`setnx?` にすると
    # 副作用の無い問い合わせに見えるので、Redis のコマンド名のまま残す。
    def setnx(key, value) # rubocop:disable Naming/PredicateMethod
      value = '' if value.nil?
      return redis.call('SET', create_key(key), value, 'NX') == 'OK'
    end

    # 期限付きで一度だけ獲得する SET（`SET key 1 NX EX ttl`）。獲得できたとき true。
    #
    # ⚠⚠ **1 コマンド・再送なし（5.37.0 リリース前レビューの赤）。**
    # `key?` → `setex` の 2 段で書いていた `report_error` のデッドマンは、
    # - `key?` の中身が **`KEYS`**（DB 全体を O(N) で走査して Redis を塞ぐ）で、
    #   Mastodon と共有しているインスタンスを、**障害の最中に要求のたびに**塞いでいた
    # - `setex` は ginseng-redis の再送（1 秒 × 3 回）を踏むので、書き込みを拒む Redis
    #   （MISCONF・OOM・READONLY）では **5xx のたびに puma のスレッドが約 2 秒止まった**
    # ⚠ 例外は呼び出し側へ上げる（握らない）。書けないときにどう倒すかは呼び出し側が決める。
    def acquire(key, ttl) # rubocop:disable Naming/PredicateMethod
      return redis.call('SET', create_key(key), '1', 'NX', 'EX', ttl.to_i) == 'OK'
    end

    # トークン付きのロックを取る（`SET key token NX EX ttl`）。取れたとき true (#4742)。
    #
    # 🔴 **切れた接続を掴んでいたら、1 回だけ撃ち直す。**`redis-client` は既定で再接続しないので、
    # Redis の再起動後、プールに残った接続で撃った最初のコマンドは必ず `ConnectionError` になる。
    # ロックはそこで fail-open するのに、同じ要求の `get` / `set` は ginseng-redis の再送で通るので、
    # **利用者には正常な 200 のままロックだけが外れていた。**
    #
    # ⚠ **待たない。**落ちた接続はプールから捨てられており、撃ち直しは新しい接続で行われる。
    # ginseng-redis の再送（1 秒 × 3 回）に載せないのは、Redis が本当に落ちているとき
    # puma のスレッドを止めないため。2 回目も落ちたら呼び出し側の fail-open に任せる。
    # ⚠ **タイムアウトは撃ち直さない。**詰まっている相手に待ちを 2 倍にするだけなので。
    # ⚠⚠ **撃ち直しで NX に負けたら、値が自分の token かを見る。**1 回目が届いたあとで
    # 応答だけ落ちた場合、鍵は自分のものなので「他者が保持中」と答えてはいけない。
    # ⚠ `key` は `create_key` 済みのものを渡す。
    def acquire_token(key, token, ttl)
      retried = false
      begin
        return true if redis.call('SET', key, token, 'NX', 'EX', ttl.to_i) == 'OK'
      rescue RedisClient::ConnectionError => e
        raise if retried || e.is_a?(RedisClient::TimeoutError)
        retried = true
        retry
      end
      return retried && redis.call('GET', key) == token
    end

    # 値が token のときだけ鍵を消す（compare-and-delete）。消したとき true (#4742)。
    #
    # ⚠ `acquire_token` と同じく、切れた接続なら 1 回だけ撃ち直す。**何度撃っても結果が
    # 変わらない**（消えたあとは token が合わない）ので、撃ち直しに副作用は無い。
    # ⚠ ここで落ちると鍵が TTL まで残り、その間の書き込みが全部 409 になる。
    def release_token(key, token)
      retried = false
      begin
        return redis.call('EVAL', RELEASE_TOKEN_SCRIPT, 1, key, token).to_i.positive?
      rescue RedisClient::ConnectionError => e
        raise if retried || e.is_a?(RedisClient::TimeoutError)
        retried = true
        retry
      end
    end

    def clear
      bar = ProgressBar.create(total: all_keys.count)
      all_keys.each do |key|
        unlink(key)
      ensure
        bar&.increment
      end
      bar&.finish
      log(method: __method__, prefix:)
    end

    def self.dsn
      return Ginseng::Redis::DSN.parse(config['/user_config/redis/dsn'])
    end

    def self.health
      new.get('1')
      return {status: 'OK'}
    rescue => e
      return {error: e.message, status: 'NG'}
    end
  end
end
