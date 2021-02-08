module Mulukhiya
  class MediaFeedRendererTest < TestCase
    def setup
      @renderer = MediaFeedRenderer.new
    end

    def test_to_s
      r = @renderer.to_s
      assert_equal(r.each_line.to_a.first.chomp, '<?xml version="1.0" encoding="UTF-8"?>')
      assert(r.include?('<entry>')) unless Environment.ci?
    end
  end
end
