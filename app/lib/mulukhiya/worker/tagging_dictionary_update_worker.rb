module Mulukhiya
  class TaggingDictionaryUpdateWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless Handler.create(:dictionary_tag).all.present?
      return super
    end

    def perform(params = {})
      # every 10m。辞書を 1 つも持たないサーバーでも TaggingDictionary#refresh が
      # 外部の辞書 API を叩いてしまう (#4506)。
      return if disable?
      dictionary = TaggingDictionary.new(lazy: true)
      # ⚠ **投稿の経路からの依頼（`'cold' => true`・#4628）は、もう埋まっていれば何もしない。**
      # Sidekiq が止まっていた間に溜まった依頼が、復帰した瞬間にまとめて上流を叩かないため。
      # ⚠ 何もしなかった回も 1 行残す。残さないと、溜まった依頼が「start → done だけ」で
      # 並び、更新ワーカーが空振りしているように見える（5.41.0 のリリース前レビュー）。
      if flag?(params, :cold) && dictionary.cache.is_a?(Hash)
        log(entries: dictionary.size, cold: true, skipped: true)
        return dictionary
      end
      # ⚠ **手動の更新（管理画面・rake）は `'force' => true` を渡す (#4690)。**ソースごとの
      # 取得間隔を無視して全部取りにいく。定時（sidekiq-scheduler）は引数なし＝間隔に従う。
      dictionary.refresh(force: flag?(params, :force))
      log(entries: dictionary.size, force: flag?(params, :force), cold: flag?(params, :cold))
      return dictionary
    end

    private

    # ⚠⚠ **キーは文字列でもシンボルでも来る（PR #4828 の Codex P2）。**Sidekiq を通ると JSON を
    # 往復して文字列になり、development / test では `Worker.perform_async` が
    # `deep_symbolize_keys` してから同期で呼ぶのでシンボルになる。
    # ⚠ 値は真偽値の `true` だけを通す（`'true'` や 1 で、黙って全取得に倒さない）。
    def flag?(params, name)
      return false unless params.is_a?(Hash)
      return params[name.to_s] == true || params[name.to_sym] == true
    end
  end
end
