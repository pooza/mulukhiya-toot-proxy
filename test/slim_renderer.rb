module Mulukhiya
  class SlimRendererTest < TestCase
    def setup
      @renderer = SlimRenderer.new
      @renderer.template = 'app_home'
    end

    def test_type
      assert_equal(@renderer.type, 'text/html; charset=UTF-8')
    end

    def test_status
      assert_equal(@renderer.status, 200)
      @renderer.status = 404
      assert_equal(@renderer.status, 404)
    end

    def test_params
      assert_kind_of(Hash, @renderer.params)
    end

    def test_to_s
      assert(@renderer.to_s.present?)
    end
  end
end
