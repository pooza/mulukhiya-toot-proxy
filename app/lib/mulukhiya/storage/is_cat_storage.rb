module Mulukhiya
  # ⚠ **読み書きとも 1 コマンド・再送なし。**`IsCatService` の締切は HTTP と名前解決しか
  # 包んでいないので、ginseng-redis の再送（1 回あたり約 2 秒）を踏むと、Redis の障害中に
  # acct ごとに待たされて 5 秒を超える（5.43.0 のリリース前レビュー）。読めなければ取りに行き、
  # 書けなければ覚えないだけ。
  class IsCatStorage < Redis
    def get(acct)
      return nil unless entry = redis.call('GET', create_key(acct))
      return JSON.parse(entry)
    rescue => e
      e.log(acct:)
      return nil
    end

    def set(acct, value)
      redis.call('SET', create_key(acct), value.to_json, 'EX', ttl.to_i)
    rescue => e
      e.log(acct:)
    end

    # 取れなかった acct (#4677)。`is_cat` は nil で、寿命は成功より短い。
    #
    # ⚠ 締切をほぼ使い切った後に呼ばれるので、特に再送を踏めない（PR #4842 の Codex P2）。
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
