module Mulukhiya
  # Annict のエピソード辞書（`GET /tagging/dic/annict/episodes`）の直近の成功結果 (#4801)。
  #
  # ⚠ **読み書きの失敗は握って nil / false を返す。**キャッシュは Annict が遅いときの
  # 保険なので、Redis の不調で本来返せる応答まで落とさない。
  class AnnictDictionaryStorage < Redis
    def get(key)
      return nil unless entry = super
      values = JSON.parse(entry)
      return nil unless values.is_a?(Hash) && values['entries'].is_a?(Hash)
      return values
    rescue => e
      e.log(key:)
      return nil
    end

    def set(key, entries)
      setex(key, ttl, {entries:, updated_at: Time.now.to_i}.to_json)
      return true
    rescue => e
      e.log(key:)
      return false
    end

    def ttl
      return config['/service/annict/dictionary/cache/ttl']
    end

    def prefix
      return 'annict_dictionary'
    end
  end
end
