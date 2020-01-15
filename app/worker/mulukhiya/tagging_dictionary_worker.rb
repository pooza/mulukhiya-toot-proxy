module Mulukhiya
  class TaggingDictionaryWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def initialize
      @logger = Logger.new
    end

    def perform
      TaggingDictionary.new.refresh
    end
  end
end
