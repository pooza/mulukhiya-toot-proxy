module Mulukhiya
  class MediaFeedRendererTest < TestCase
    def disable?
      return true unless Environment.dbms_class&.config?
      return true unless controller_class.feed?
      return super
    end

    def setup
      return if disable?
      @renderer = MediaFeedRenderer.new
    end

    def test_to_s
      r = @renderer.to_s

      assert_equal('<?xml version="1.0" encoding="UTF-8"?>', r.each_line.to_a.first.chomp)
      assert_includes(r, '<item>')
    end

    def test_uri
      assert_kind_of(Ginseng::URI, MediaFeedRenderer.uri)
      assert_predicate(MediaFeedRenderer.uri, :absolute?)
      assert_kind_of(HTTParty::Response, http.get(MediaFeedRenderer.uri))
    end
  end
end
