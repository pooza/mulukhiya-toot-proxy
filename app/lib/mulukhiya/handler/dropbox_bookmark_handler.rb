module Mulukhiya
  class DropboxBookmarkHandler < BookmarkHandler
    def worker_class
      return DropboxClippingWorker
    end
  end
end
