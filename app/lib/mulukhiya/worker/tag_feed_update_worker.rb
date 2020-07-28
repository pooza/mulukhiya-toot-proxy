module Mulukhiya
  class TagFeedUpdateWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform
      TagAtomFeedRenderer.cache_all
    end
  end
end
