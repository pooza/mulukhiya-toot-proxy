module Mulukhiya
  class GrowiBookmarkHandler < BookmarkHandler
    def disable?
      return false unless sns.account.growi
      return super
    end

    def worker_class
      return GrowiClippingWorker
    end
  end
end
