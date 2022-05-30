module Mulukhiya
  class GrowiBookmarkHandler < BookmarkHandler
    def disable?
      return true unless sns.account&.growi
      return super
    end

    def toggleable?
      return false unless controller_class.growi?
      return super
    end

    def worker_class
      return GrowiClippingWorker
    end
  end
end
