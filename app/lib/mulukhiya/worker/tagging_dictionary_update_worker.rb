module Mulukhiya
  class TaggingDictionaryUpdateWorker < Worker
    sidekiq_options retry: false

    def perform(params = {})
      TaggingDictionary.new.refresh
    end
  end
end
