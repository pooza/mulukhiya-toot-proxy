module Mulukhiya
  class TaggingDictionaryUpdateWorker
    include Sidekiq::Worker
    sidekiq_options retry: false, lock: :until_executed

    def perform
      TaggingDictionary.new.refresh
    end
  end
end
