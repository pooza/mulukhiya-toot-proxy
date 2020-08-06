module Mulukhiya
  class AnnouncementWorkerTest < TestCase
    def setup
      @worker = AnnouncementWorker.new
    end

    def test_announcements
      return unless Environment.controller_class.announcement?
      @worker.announcements do |entry|
        assert_kind_of(Hash, entry)
      end
    end
  end
end
