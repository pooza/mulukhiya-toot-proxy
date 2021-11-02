module Mulukhiya
  class FeedUpdateWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless controller_class.feed?
      return false
    end

    def perform(params = {})
      CustomFeed.all(&:update)
    end
  end
end
