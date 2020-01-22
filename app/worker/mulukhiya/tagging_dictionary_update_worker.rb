module Mulukhiya
  class TaggingDictionaryUpdateWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform
      TaggingDictionary.new.refresh
    end
  end
end
