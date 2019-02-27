module MulukhiyaTootProxy
  class FetchTaggingDictionaryWorker
    include Sidekiq::Worker

    def perform
      TaggingDictionary.new.create
    end
  end
end
