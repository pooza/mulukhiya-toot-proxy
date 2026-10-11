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
      dictionary = TaggingDictionary.new
      # ⚠ **手動の更新（管理画面・rake）は `'force' => true` を渡す (#4690)。**ソースごとの
      # 取得間隔を無視して全部取りにいく。定時（sidekiq-scheduler）は引数なし＝間隔に従う。
      dictionary.refresh(force: force?(params))
      log(entries: dictionary.size, force: force?(params))
      return dictionary
    end

    private

    # ⚠⚠ **キーは文字列でもシンボルでも来る（PR #4828 の Codex P2）。**Sidekiq を通ると JSON を
    # 往復して文字列になり、development / test では `Worker.perform_async` が
    # `deep_symbolize_keys` してから同期で呼ぶのでシンボルになる。
    # ⚠ 値は真偽値の `true` だけを通す（`'true'` や 1 で、黙って全取得に倒さない）。
    def force?(params)
      return false unless params.is_a?(Hash)
      return params['force'] == true || params[:force] == true
    end
  end
end
