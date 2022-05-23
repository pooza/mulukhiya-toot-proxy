module Mulukhiya
  class NextcloudBookmarkHandler < BookmarkHandler
    def toggleable?
      return false unless controller_class.nextcloud?
      return false unless sns.account&.nextcloud
      return super
    end

    def worker_class
      return NextcloudClippingWorker
    end
  end
end
