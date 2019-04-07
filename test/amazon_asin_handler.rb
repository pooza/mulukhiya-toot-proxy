module MulukhiyaTootProxy
  class AmazonASINHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('amazon_asin')
      @config = Config.instance
      @config['/amazon/associate_tag'] = 'pooza'
    end

    def test_exec
      @config['/amazon/affiliate'] = false
      r = @handler.exec({'status' => 'https://www.amazon.co.jp/日本語の長い長い商品名/dp/B07CJ4KH1T/ref=sr_1_1?s=hobby&ie=UTF8&qid=1529591544&sr=1-1'})
      assert_equal(@handler.result[:entries], ['https://www.amazon.co.jp/日本語の長い長い商品名/dp/B07CJ4KH1T/ref=sr_1_1?s=hobby&ie=UTF8&qid=1529591544&sr=1-1'])
      assert_equal(r['status'], 'https://www.amazon.co.jp/dp/B07CJ4KH1T')

      @config['/amazon/affiliate'] = true
      r = @handler.exec({'status' => 'https://www.amazon.co.jp/日本語の長い長い商品名/dp/B07CJ4KH1T/ref=sr_1_1?s=hobby&ie=UTF8&qid=1529591544&sr=1-1'})
      assert_equal(r['status'], 'https://www.amazon.co.jp/dp/B07CJ4KH1T?tag=pooza')
    end
  end
end
