module Mulukhiya
  class LemmyBookmarkHandler < BookmarkHandler
    def disable?
      return true unless sns.account&.lemmy
      return super
    end

    def toggleable?
      return false unless controller_class.lemmy?
      return super
    end

    def worker_class
      return LemmyClippingWorker
    end
  end
end
