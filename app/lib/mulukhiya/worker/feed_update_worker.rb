module Mulukhiya
  class FeedUpdateWorker
    include Sidekiq::Worker
    include Package
    include SNSMethods
    sidekiq_options retry: false

    def perform
      return unless controller_class.feed?
      CustomFeed.all(&:update)
    end
  end
end
