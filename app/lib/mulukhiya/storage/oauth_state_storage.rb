module Mulukhiya
  class OAuthStateStorage < Redis
    TTL = 600

    def get(key)
      return nil unless entry = super
      return JSON.parse(entry, symbolize_names: true)
    rescue => e
      e.log(key:)
      return nil
    end

    def set(key, values)
      setex(key, TTL, values.to_json)
    end

    # ⚠⚠ **読み出しと削除を分けない（PR #4714 の Codex P2）。**`get` → `unlink` の
    # 2 段だと、**同じ state を使った同時 POST が両方とも通る**。`GETDEL` は
    # 1 コマンドで取り出しと削除を行うので、一度きりが実際に守られる。
    #
    # ⚠ `GETDEL` は Redis 6.2 以降。本番 3 台とローカルはいずれも 8.x（実測）。
    def consume(key)
      return nil unless raw = redis.call('GETDEL', create_key(key))
      return JSON.parse(raw, symbolize_names: true)
    rescue => e
      e.log(key:)
      return nil
    end

    def prefix
      return 'oauth_state'
    end
  end
end
