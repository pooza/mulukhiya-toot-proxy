module Mulukhiya
  class AnnounceTest < TestCase
    def setup
      @announce = Announce.new
    end

    def test_load
      assert_kind_of(Hash, @announce.load)
    end

    def test_count
      assert_kind_of(Integer, @announce.count)
    end

    def test_fetch
      assert_kind_of(Array, @announce.fetch)
      @announce.fetch.first(5).each do |entry|
        assert_kind_of(Hash, entry)
        assert(entry[:id].present?)
        assert(entry[:content].present?)
      end
    end
  end
end
