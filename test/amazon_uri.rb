require 'addressable/uri'

module MulukhiyaTootProxy
  class AmazonURITest < Test::Unit::TestCase
    def test_shortenable?
      uri = AmazonURI.parse('https://google.com')
      assert_false(uri.shortenable?)

      uri = AmazonURI.parse('https://www.amazon.co.jp/長い長い長い商品名/dp/hoge')
      assert_true(uri.shortenable?)
    end

    def test_amazon?
      uri = AmazonURI.parse('https://google.com')
      assert_false(uri.amazon?)

      uri = AmazonURI.parse('https://www.amazon.co.jp')
      assert_true(uri.amazon?)

      uri = AmazonURI.parse('https://www.amazon.co.jp/長い長い長い商品名/dp/hoge')
      assert_true(uri.amazon?)
    end

    def test_asin
      uri = AmazonURI.parse('https://www.amazon.co.jp')
      assert_nil(uri.asin)

      uri = AmazonURI.parse('https://www.amazon.co.jp/長い長い長い商品名/dp/hoge')
      assert_equal(uri.asin, 'hoge')
    end

    def test_shorten
      uri = AmazonURI.parse('https://www.amazon.co.jp')
      assert_equal(uri.shorten.to_s, 'https://www.amazon.co.jp')

      uri = AmazonURI.parse('https://www.amazon.co.jp/長い長い長い商品名/dp/hoge')
      assert_equal(uri.shorten.to_s, 'https://www.amazon.co.jp/dp/hoge')
    end
  end
end
