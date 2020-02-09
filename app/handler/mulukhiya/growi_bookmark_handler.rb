module Mulukhiya
  class GrowiBookmarkHandler < BookmarkHandler
    def worker_class
      return GrowiClippingWorker
    end
  end
end
