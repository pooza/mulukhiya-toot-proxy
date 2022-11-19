module Mulukhiya
  class AmazonURITest < TestCase
    def test_shortenable?
      uri = AmazonURI.parse('https://google.com')

      assert_false(uri.shortenable?)

      uri = AmazonURI.parse('https://www.amazon.co.jp/長い長い長い商品名/dp/hoge')

      assert_predicate(uri, :shortenable?)
    end

    def test_amazon?
      uri = AmazonURI.parse('https://google.com')

      assert_false(uri.amazon?)

      uri = AmazonURI.parse('https://www.amazon.co.jp')

      assert_predicate(uri, :amazon?)

      uri = AmazonURI.parse('https://www.amazon.co.jp/長い長い長い商品名/dp/hoge')

      assert_predicate(uri, :amazon?)
    end

    def test_asin
      uri = AmazonURI.parse('https://www.amazon.co.jp')

      assert_nil(uri.asin)

      uri = AmazonURI.parse('https://www.amazon.co.jp/長い長い長い商品名/dp/hoge')

      assert_equal('hoge', uri.asin)
    end

    def test_shorten
      uri = AmazonURI.parse('https://www.amazon.co.jp')

      assert_equal('https://www.amazon.co.jp', uri.shorten.to_s)

      uri = AmazonURI.parse('https://www.amazon.co.jp/長い長い長い商品名/dp/hoge')

      assert_equal('https://www.amazon.co.jp/dp/hoge', uri.shorten.to_s)
    end
  end
end
