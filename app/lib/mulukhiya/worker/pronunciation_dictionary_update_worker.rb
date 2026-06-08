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
      dictionary.update
      log(entries: dictionary.size)
      return dictionary
    end
  end
end
