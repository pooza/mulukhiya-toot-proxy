module Mulukhiya
  # 値を JSON で読み書きするストレージの共通部分 (#4898)。
  #
  # 約 10 本のストレージが同じ形の `get` / `set` を写していた。写しの 1 本
  # （`MediaMetadataStorage#get`）は、無い鍵を引くと打ち間違いで NameError を投げていた。
  #
  # ⚠ ginseng-redis には返さない（2026-11-10 判断）。使っているのはモロヘイヤだけで、
  # 読めない値を握ってログに残す倒し方もモロヘイヤの事情に合わせてある。
  # 返せる形にはしてあるので、他で要るようになったら持っていけばよい。
  #
  # 差し替え口:
  # - `ttl` — 返せば期限付き（`SETEX`）で書く。既定は nil（期限なし）
  # - `symbolize_names?` — 読んだ Hash のキーをシンボルにするか。既定は false
  # - `default_value` — 鍵が無いとき・読めないときに返す値。既定は nil
  class JSONStorage < Redis
    def get(key)
      return default_value unless entry = super
      return JSON.parse(entry, symbolize_names: symbolize_names?)
    rescue => e
      e.log(key:)
      return default_value
    end

    def set(key, value, ttl: self.ttl)
      return setex(key, ttl, value.to_json) if ttl
      return super(key, value.to_json)
    end

    def ttl
      return nil
    end

    def symbolize_names?
      return false
    end

    def default_value
      return nil
    end
  end
end
