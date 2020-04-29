module Mulukhiya
  class DropboxBookmarkHandler < BookmarkHandler
    def disable?
      return super || sns.account.dropbox.nil?
    end

    def worker_class
      return DropboxClippingWorker
    end
  end
end
