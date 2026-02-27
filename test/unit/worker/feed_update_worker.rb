module Mulukhiya
  class FeedUpdateWorkerTest < TestCase
    def disable?
      return true unless controller_class.feed?
      return true unless CustomFeed.all.present?
      return super
    end

    def setup
      return if disable?
      @worker = Worker.create(:feed_update)
    end

    def test_perform
      @worker.perform
    end
  end
end
