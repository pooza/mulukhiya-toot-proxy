module Mulukhiya
  class TagFeedRendererTest < TestCase
    def setup
      @renderer = TagFeedRenderer.new
      @renderer.tag = TagContainer.default_tag_bases.first
    end

    def test_tag
      assert_equal(@renderer.tag, TagContainer.default_tag_bases.first)
    end

    def test_limit
      assert_equal(@renderer.limit, 100)
    end

    def test_to_s
      r = @renderer.to_s
      assert_equal(r.each_line.to_a.first.chomp, '<?xml version="1.0" encoding="UTF-8"?>')
      assert(r.include?('<entry>')) unless Environment.ci?
    end

    def test_exist?
      assert_boolean(@renderer.exist?)
    end
  end
end
