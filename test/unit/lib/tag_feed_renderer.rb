module Mulukhiya
  class TagFeedRendererTest < TestCase
    def disable?
      return true unless controller_class.feed?
      return true unless DefaultTagHandler.tags.present?
      return super
    end

    def setup
      return if disable?
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
    end

    def test_exist?
      assert_boolean(@renderer.exist?)
    end
  end
end
