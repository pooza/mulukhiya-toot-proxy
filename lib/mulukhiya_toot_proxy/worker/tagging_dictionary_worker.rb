module MulukhiyaTootProxy
  class TaggingDictionaryWorker
    include Sidekiq::Worker

    def perform
      TaggingDictionary.new.refresh
    end
  end
end
