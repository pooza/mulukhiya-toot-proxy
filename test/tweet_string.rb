module Mulukhiya
  class TweetStringTest < TestCase
    def setup
      @config = Config.instance
    end

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

      str = TweetString.new('ああああefefx')
      assert_nil(str.index('hoge'))
    end

    def test_valid?
      str = TweetString.new('あ' * 140)
      assert(str.valid?)

      str = TweetString.new('あ' * 141)
      assert_false(str.valid?)

      str = TweetString.new('A' * 280)
      assert(str.valid?)

      str = TweetString.new('A' * 281)
      assert_false(str.valid?)
    end

    def test_extra_tags
      @config['/twitter/status/default_tags'] = ['キュアスタ']

      tweet = TweetString.new('ちょうおもしろい。')
      assert_equal(tweet.extra_tags, ['#キュアスタ'])

      tweet = TweetString.new('ちょうおもしろい。 #キュアスタ')
      assert_equal(tweet.extra_tags, [])

      @config['/twitter/status/default_tags'] = []

      tweet = TweetString.new('ちょうおもしろい。')
      assert_equal(tweet.extra_tags, [])

      tweet = TweetString.new('ちょうおもしろい。 #キュアスタ')
      assert_equal(tweet.extra_tags, [])
    end

    def test_body_length_limit
      @config['/twitter/status/default_tags'] = ['キュアスタ']
      tweet = TweetString.new('ちょうおもしろい。')
      assert_equal(tweet.body_length_limit, 120)

      @config['/twitter/status/default_tags'] = []
      tweet = TweetString.new('ちょうおもしろい。')
      assert_equal(tweet.body_length_limit, 127)
    end
  end
end
