module MulukhiyaTootProxy
  class TaggingDictionaryWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform
      TaggingDictionary.new.refresh
    end
  end
end
