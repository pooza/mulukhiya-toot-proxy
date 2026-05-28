module Mulukhiya
  class MediaCatalogDisabledRendererTest < TestCase
    def test_apply_json_sets_status_and_payload
      renderer = Ginseng::Web::JSONRenderer.new
      result = MediaCatalogDisabledRenderer.apply!(renderer, endpoint: '/media')

      assert_same(renderer, result)
      assert_equal(MediaCatalogDisabledRenderer::STATUS, renderer.status)
      assert_equal(
        MediaCatalogDisabledRenderer::EMPTY_PAYLOAD,
        renderer.instance_variable_get(:@message),
      )
    end

    def test_apply_rss_only_sets_status
      renderer = Ginseng::Web::RSS20FeedRenderer.new
      before = renderer.instance_variable_get(:@message)
      MediaCatalogDisabledRenderer.apply!(renderer, endpoint: '/feed/media')

      assert_equal(MediaCatalogDisabledRenderer::STATUS, renderer.status)
      assert_equal(before, renderer.instance_variable_get(:@message))
    end
  end
end
