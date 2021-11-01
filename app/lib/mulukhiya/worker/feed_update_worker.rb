module Mulukhiya
  class FeedUpdateWorker < Worker
    sidekiq_options retry: false

    def perform(params = {})
      return unless controller_class.feed?
      CustomFeed.all(&:update)
    end
  end
end
