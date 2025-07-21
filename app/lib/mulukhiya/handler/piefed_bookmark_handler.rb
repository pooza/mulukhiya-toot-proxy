module Mulukhiya
  class PiefedBookmarkHandler < BookmarkHandler
    def disable?
      return true unless controller_class.piefed?
      return true unless sns.account&.piefed
      return super
    end

    def worker_class
      return PiefedClippingWorker
    end
  end
end
