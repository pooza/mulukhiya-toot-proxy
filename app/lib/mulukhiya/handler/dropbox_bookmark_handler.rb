module Mulukhiya
  class DropboxBookmarkHandler < BookmarkHandler
    def disable?
      return false unless sns.account.dropbox
      return super
    end

    def worker_class
      return DropboxClippingWorker
    end
  end
end
