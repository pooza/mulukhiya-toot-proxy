module Mulukhiya
  class AtomFeedRendererTest < TestCase
    def setup
      @renderer = AtomFeedRenderer.new
    end

    def test_type
      assert_equal(@renderer.type, 'application/atom+xml; charset=UTF-8')
    end

    def test_to_s
      assert_equal(@renderer.to_s.each_line.to_a.first.chomp, '<?xml version="1.0" encoding="UTF-8"?>')
    end

    def test_entries
      assert_kind_of(Array, @renderer.entries)
    end
  end
end
