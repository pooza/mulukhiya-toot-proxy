module Mulukhiya
  class ScriptRendererTest < TestCase
    def setup
      @renderer = ScriptRenderer.new
      @renderer.name = 'mulukhiya_lib'
    end

    def test_to_s
      assert_kind_of(String, @renderer.to_s)
      assert_predicate(@renderer.to_s, :present?)
    end
  end
end
