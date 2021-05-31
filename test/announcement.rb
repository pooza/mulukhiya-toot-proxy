module Mulukhiya
  class AnnouncementTest < TestCase
    def setup
      @announcements = Announcement.instance
    end

    def test_load
      assert_kind_of(Hash, @announcements.load)
    end

    def test_count
      assert_kind_of(Integer, @announcements.count)
    end

    def test_fetch
      assert_kind_of(Array, @announcements.fetch)
      @announcements.fetch.first(5).each do |entry|
        assert_kind_of(Hash, entry)
        assert(entry[:id].present?)
        assert(entry[:content].present?)
      end
    end
  end
end
