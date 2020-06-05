module Mulukhiya
  class TweetStringTest < TestCase
    def test_length
      str = TweetString.new('ああああえええeee')
      assert_equal(str.length, 8.5)

      str = TweetString.new('ああああ')
      assert_equal(str.length, 4)
    end

    def test_index
      str = TweetString.new('ああああえええeee')
      assert_equal(str.index('eee'), 7)

      str = TweetString.new('ああああefef')
      assert_equal(str.index('f'), 4.5)

      str = TweetString.new('ああああefefx')
      assert_equal(str.index('fx'), 5.5)
    end

    def test_max_length
      assert_kind_of(Integer, TweetString.max_length)
      assert_false(TweetString.max_length.zero?)
    end

    def test_tags
      assert_kind_of(Array, TweetString.tags)
    end
  end
end
