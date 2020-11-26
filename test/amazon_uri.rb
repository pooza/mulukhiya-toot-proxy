module Mulukhiya
  class AmazonURITest < TestCase
    def test_shortenable?
      uri = AmazonURI.parse('https://google.com')
      assert_false(uri.shortenable?)

      uri = AmazonURI.parse('https://www.amazon.co.jp/長い長い長い商品名/dp/hoge')
      assert(uri.shortenable?)
    end

    def test_amazon?
      uri = AmazonURI.parse('https://google.com')
      assert_false(uri.amazon?)

      uri = AmazonURI.parse('https://www.amazon.co.jp')
      assert(uri.amazon?)

      uri = AmazonURI.parse('https://www.amazon.co.jp/長い長い長い商品名/dp/hoge')
      assert(uri.amazon?)
    end

    def test_asin
      uri = AmazonURI.parse('https://www.amazon.co.jp')
      assert_nil(uri.asin)

      uri = AmazonURI.parse('https://www.amazon.co.jp/長い長い長い商品名/dp/hoge')
      assert_equal(uri.asin, 'hoge')
    end

    def test_associate_tag
      uri = AmazonURI.parse('https://www.amazon.co.jp/dp/B00LNCTX48?tag=bshockfortrbl-22')
      assert_equal(uri.associate_tag, 'bshockfortrbl-22')

      uri.associate_tag = nil
      assert_nil(uri.associate_tag)

      uri.associate_tag = 'hoge'
      assert_equal(uri.associate_tag, 'hoge')
    end

    def test_shorten
      uri = AmazonURI.parse('https://www.amazon.co.jp')
      assert_equal(uri.shorten.to_s, 'https://www.amazon.co.jp')

      uri = AmazonURI.parse('https://www.amazon.co.jp/長い長い長い商品名/dp/hoge')
      assert_equal(uri.shorten.to_s, 'https://www.amazon.co.jp/dp/hoge')

      uri = AmazonURI.parse('https://www.amazon.co.jp/長い長い長い商品名/dp/hoge')
      uri.associate_tag = 'bshockfortrbl-22'
      assert_equal(uri.shorten.to_s, 'https://www.amazon.co.jp/dp/hoge?tag=bshockfortrbl-22')

      uri = AmazonURI.parse('https://www.amazon.co.jp/長い長い長い商品名/dp/hoge?a=eee')
      assert_equal(uri.shorten.to_s, 'https://www.amazon.co.jp/dp/hoge')
      uri.associate_tag = 'bshockfortrbl-22'
      assert_equal(uri.shorten.to_s, 'https://www.amazon.co.jp/dp/hoge?tag=bshockfortrbl-22')
    end

    def test_image_uri
      uri = AmazonURI.parse('https://www.amazon.co.jp/dp/B08JH42SHR')
      assert_kind_of(Ginseng::URI, uri.image_uri) if uri.image_uri
      assert(uri.image_uri.absolute?) if uri.image_uri
    end
  end
end
