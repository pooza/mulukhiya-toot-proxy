module Mulukhiya
  class TagFeedRendererTest < TestCase
    def disable?
      return true if DefaultTagHandler.tags.empty?
      return super
    end

    def setup
      @renderer = TagFeedRenderer.new
      @renderer.tag = DefaultTagHandler.tags.first
    end

    def test_tag
      assert_equal(@renderer.tag, DefaultTagHandler.tags.first)
    end

    def test_limit
      assert_equal(100, @renderer.limit)
    end

    def test_to_s
      r = @renderer.to_s
      assert_equal('<?xml version="1.0" encoding="UTF-8"?>', r.each_line.to_a.first.chomp)
      assert_includes(r, '<item>')
    end

    def test_exist?
      assert_boolean(@renderer.exist?)
    end
  end
end
