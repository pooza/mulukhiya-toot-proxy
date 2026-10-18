module Mulukhiya
  class IsCatStorage < Redis
    def get(acct)
      return nil unless entry = super
      return JSON.parse(entry)
    rescue => e
      e.log(acct:)
      return nil
    end

    def set(acct, value)
      setex(acct, ttl, value.to_json)
    end

    # 取れなかった acct (#4677)。`is_cat` は nil で、寿命は成功より短い。
    #
    # ⚠ **1 コマンド・再送なし（PR #4842 の Codex P2）。**締切をほぼ使い切った後に呼ばれるので、
    # `setex` の再送（ginseng-redis の 1 秒 × 3 回）を踏むと、書き込みを拒む Redis（READONLY・
    # MISCONF・OOM）で応答が 5 秒を超える。書けなければ覚えないだけ（次の機会に取り直す）。
    def remember_failure(acct)
      value = {is_cat: nil, failed: true}.to_json
      redis.call('SET', create_key(acct), value, 'EX', failure_ttl.to_i)
    rescue => e
      e.log(acct:)
    end

    def ttl
      return config['/account/is_cat/cache/ttl']
    end

    def failure_ttl
      return config['/account/is_cat/cache/failure_ttl']
    end

    def prefix
      return 'is_cat'
    end
  end
end
