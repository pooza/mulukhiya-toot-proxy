module Mulukhiya
  class NextcloudBookmarkHandler < BookmarkHandler
    def disable?
      return true unless controller_class.nextcloud?
      return true unless sns.account&.nextcloud
      return super
    end

    def worker_class
      return NextcloudClippingWorker
    end
  end
end
