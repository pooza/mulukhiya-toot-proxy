module Mulukhiya
  class PronunciationDictionaryUpdateWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless PronunciationDictionary.new.enabled?
      return super
    end

    def perform(params = {})
      # sidekiq-scheduler は perform_async を介さず Sidekiq::Client.push 直叩きで
      # enqueue するため、disable? を perform 側でも評価する。
      return if disable?
      dictionary = PronunciationDictionary.new
      entries = dictionary.update
      # 件数は update の戻り値 (保存できた entries / 失敗時 nil) から取る。
      # dictionary.size 経由だと cold-cache 時に entries → enqueue_update_and_empty
      # が走り、fetch / save 失敗ワーカーが次のワーカーを無限に再 enqueue する
      # (retry:false でも防げない) (#4405 Codex P1)。
      log(entries: entries&.size || 0)
      return dictionary
    end
  end
end
