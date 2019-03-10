module MulukhiyaTootProxy
  class TaggingDictionaryWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform
      TaggingDictionary.instance.refresh
    end
  end
end
