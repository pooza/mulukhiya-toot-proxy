module Mulukhiya
  class FeedUpdateWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless controller_class.feed?
      return true unless CustomFeed.all.present?
      return super
    end

    def perform(params = {})
      CustomFeed.all(&:update)
    end
  end
end
