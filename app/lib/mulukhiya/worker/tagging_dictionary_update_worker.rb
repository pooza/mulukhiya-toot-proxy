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
      dictionary.refresh
      log(entries: dictionary.size)
      return dictionary
    end
  end
end
