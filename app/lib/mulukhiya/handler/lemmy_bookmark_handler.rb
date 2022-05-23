module Mulukhiya
  class LemmyBookmarkHandler < BookmarkHandler
    def toggleable?
      return false unless controller_class.lemmy?
      return false unless sns.account&.lemmy
      return super
    end

    def worker_class
      return LemmyClippingWorker
    end
  end
end
