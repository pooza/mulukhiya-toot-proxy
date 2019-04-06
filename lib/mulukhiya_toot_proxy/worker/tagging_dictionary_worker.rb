module MulukhiyaTootProxy
  class TaggingDictionaryWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform
      TaggingDictionary.new.refresh
    rescue => e
      @logger.error(Ginseng::Error.create(e).to_h)
    end
  end
end
