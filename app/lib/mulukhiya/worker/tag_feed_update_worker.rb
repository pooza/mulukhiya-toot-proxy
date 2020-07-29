module Mulukhiya
  class TagFeedUpdateWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform
      return unless Environment.controller_class.tag_feed?
      TagAtomFeedRenderer.cache_all
    end
  end
end
