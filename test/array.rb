module Mulukhiya
  class ArrayTest < TestCase
    def setup
      @array = [{aa: nil, ab: 12, ac: {aca: nil}}, [], 1]
    end

    def test_deep_compact
      assert_equal(@array.deep_compact, [{ab: 12}, 1])
    end

    def test_deep_compact!
      cloned = @array.deep_compact!
      assert_equal(cloned, [{ab: 12}, 1])
    end
  end
end
