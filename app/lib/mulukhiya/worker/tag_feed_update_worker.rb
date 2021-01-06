module Mulukhiya
  class TagFeedUpdateWorker
    include Sidekiq::Worker
    include SNSMethods
    sidekiq_options retry: false

    def perform
      return unless controller_class.feed?
      TagAtomFeedRenderer.cache_all
    end
  end
end
