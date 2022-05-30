module Mulukhiya
  class GrowiBookmarkHandler < BookmarkHandler
    def toggleable?
      return false unless controller_class.growi?
      return false unless sns.account&.growi
      return super
    end

    def worker_class
      return GrowiClippingWorker
    end
  end
end
