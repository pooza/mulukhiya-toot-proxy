module Mulukhiya
  class HashTest < TestCase
    def setup
      @hash = {a: {aa: nil, ab: 12, ac: {aca: nil}}, c: 1}
    end

    def test_deep_compact
      assert_equal(@hash.deep_compact, {a: {ab: 12}, c: 1})
    end

    def test_deep_compact!
      cloned = @hash.deep_compact!
      assert_equal(cloned, {a: {ab: 12}, c: 1})
    end
  end
end
