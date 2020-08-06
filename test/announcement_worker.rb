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

    def test_create_body
      return unless Environment.controller_class.announcement?
      @worker.announcements do |entry|
        assert_kind_of(String, @worker.create_body(entry, {format: :sanitized}))
        assert_kind_of(String, @worker.create_body(entry, {format: :md}))
        assert_kind_of(String, @worker.create_body(entry, {format: :md, header: true}))
      end
    end
  end
end
