module MulukhiyaTootProxy
  class TaggingDictionaryWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def initialize
      @logger = Logger.new
    end

    def perform
      TaggingDictionary.new.refresh
    rescue => e
      @logger.error(e)
    end
  end
end
