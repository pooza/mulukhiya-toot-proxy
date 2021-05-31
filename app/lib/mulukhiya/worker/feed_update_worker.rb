module Mulukhiya
  class FeedUpdateWorker
    include Sidekiq::Worker
    include Package
    include SNSMethods
    sidekiq_options retry: false, unique: :until_executed

    def perform
      return unless controller_class.feed?
      CustomFeed.instance.update
    end
  end
end
