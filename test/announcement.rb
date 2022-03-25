module Mulukhiya
  class AnnouncementTest < TestCase
    def setup
      @announcement = Announcement.new
    end

    def test_load
      assert_kind_of(Hash, @announcement.load)
    end

    def test_count
      assert_kind_of(Integer, @announcement.count)
    end

    def test_fetch
      assert_kind_of(Array, @announcement.fetch)
      @announcement.fetch.first(5).each do |entry|
        assert_kind_of(Hash, entry)
        assert_predicate(entry[:id], :present?)
        assert_predicate(entry[:content], :present?)
      end
    end
  end
end
