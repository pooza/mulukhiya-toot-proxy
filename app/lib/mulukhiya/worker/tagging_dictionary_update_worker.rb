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
      # ⚠ Sidekiq の引数は JSON を往復するので、キーは文字列で来る。
      force = params.is_a?(Hash) && params['force'] == true
      dictionary.refresh(force:)
      log(entries: dictionary.size, force:)
      return dictionary
    end
  end
end
