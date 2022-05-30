module Mulukhiya
  class NextcloudBookmarkHandler < BookmarkHandler
    def disable?
      return true unless sns.account&.nextcloud
      return super
    end

    def toggleable?
      return false unless controller_class.nextcloud?
      return super
    end

    def worker_class
      return NextcloudClippingWorker
    end
  end
end
