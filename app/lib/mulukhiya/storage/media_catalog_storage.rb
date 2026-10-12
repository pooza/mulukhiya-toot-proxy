module Mulukhiya
  class MediaCatalogStorage < Redis
    PAGE1_TTL = 180
    DEFAULT_TTL = 86_400

    def get(key)
      return nil unless entry = super
      return JSON.parse(entry, symbolize_names: true)
    rescue => e
      e.log(key:)
      return nil
    end

    def set(key, value, ttl: nil)
      ttl ||= key.to_s.match?(/\bpage:1\b/) ? PAGE1_TTL : DEFAULT_TTL
      setex(key, ttl, value.to_json)
    end

    # ⚠ **応答の形・載せる範囲を変えたら鍵を変える。**2 ページ目以降は 24 時間残るので、
    # 変えないと、未収載を含む・印の無い古い応答がデプロイ後も返り続ける
    # （`v2`: 5.41.0・公開だけ＋ `sensitive` / `spoiler_text`）。古い鍵は TTL で消える。
    def prefix
      return 'media_catalog_v2'
    end
  end
end
