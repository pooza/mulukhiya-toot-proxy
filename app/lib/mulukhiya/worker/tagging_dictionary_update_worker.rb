module Mulukhiya
  class TaggingDictionaryUpdateWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless Handler.create(:dictionary_tag).all.present?
      return super
    end

    def perform(params = {})
      dictionary = TaggingDictionary.new
      dictionary.refresh
      log(entries: dictionary.size)
      return dictionary
    end
  end
end
