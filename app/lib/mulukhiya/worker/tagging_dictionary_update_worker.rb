module Mulukhiya
  class TaggingDictionaryUpdateWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless DictionaryTagHandler.all.present?
      return super
    end

    def perform(params = {})
      TaggingDictionary.new.refresh
    end
  end
end
