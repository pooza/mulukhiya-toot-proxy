module MulukhiyaTootProxy
  class TaggingDictionaryWorker
    include Sidekiq::Worker

    def perform
      TaggingDictionary.new.create
    end
  end
end
