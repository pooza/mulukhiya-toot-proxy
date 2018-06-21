require 'mulukhiya-toot-proxy/handler/amazon_asin'

module MulukhiyaTootProxy
  class AmazonAsinHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = AmazonAsinHandler.new
      assert_equal(handler.exec('https://www.amazon.co.jp/日本語の長い長い商品名/dp/B07CJ4KH1T/ref=sr_1_1?s=hobby&ie=UTF8&qid=1529591544&sr=1-1'), 'https://www.amazon.co.jp/dp/B07CJ4KH1T')
      assert_equal(handler.result, 'AmazonAsinHandler,1')

      assert_equal(handler.exec('https://www.amazon.co.jp/商品名/dp/hoge https://www.amazon.co.jp/商品名/dp/gebo'), 'https://www.amazon.co.jp/dp/hoge https://www.amazon.co.jp/dp/gebo')
      assert_equal(handler.result, 'AmazonAsinHandler,3')
    end
  end
end
