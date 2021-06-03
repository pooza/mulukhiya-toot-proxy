module Mulukhiya
  class AnnouncerTest < TestCase
    def setup
      @annauncer = Announcer.new
    end

    def test_load
      assert_kind_of(Hash, @annauncer.load)
    end

    def test_count
      assert_kind_of(Integer, @annauncer.count)
    end

    def test_fetch
      assert_kind_of(Array, @annauncer.fetch)
      @annauncer.fetch.first(5).each do |entry|
        assert_kind_of(Hash, entry)
        assert(entry[:id].present?)
        assert(entry[:content].present?)
      end
    end
  end
end
