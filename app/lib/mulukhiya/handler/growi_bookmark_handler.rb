module Mulukhiya
  class GrowiBookmarkHandler < BookmarkHandler
    def disable?
      return super || sns.account.growi.nil?
    end

    def worker_class
      return GrowiClippingWorker
    end
  end
end
