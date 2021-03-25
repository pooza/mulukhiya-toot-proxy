module Mulukhiya
  class DropboxBookmarkHandler < BookmarkHandler
    def disable?
      return true unless sns.account.dropbox
      return super
    end

    def worker_class
      return DropboxClippingWorker
    end
  end
end
