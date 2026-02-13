module Mulukhiya
  class ScriptRendererTest < TestCase
    def setup
      @renderer = ScriptRenderer.new
      @renderer.name = 'mulukhiya_lib'
    end

    def test_to_s
      output = @renderer.to_s

      assert_kind_of(String, output)
      assert_predicate(output, :present?)
      assert_match(/export\b/, output)
    end
  end
end
