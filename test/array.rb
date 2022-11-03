module Mulukhiya
  class ArrayTest < TestCase
    def setup
      @array = [{aa: nil, ab: 12, ac: {aca: nil}}, [], 1]
    end

    def test_deep_compact
      assert_equal([{ab: 12}, 1], @array.deep_compact)
    end

    def test_deep_compact!
      cloned = @array.deep_compact!

      assert_equal([{ab: 12}, 1], cloned)
    end
  end
end
