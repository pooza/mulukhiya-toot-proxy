module Mulukhiya
  class AmazonURLHandlerTest < TestCase
    def setup
      config['/agent/test/token'] = 'hoge' if Environment.ci?
      @handler = Handler.create('amazon_url')
    end

    def test_handle_pre_toot
      config['/amazon/affiliate'] = false
      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.amazon.co.jp/日本語の長い長い商品名/dp/B07CJ4KH1T/ref=sr_1_1?s=hobby&ie=UTF8&qid=1529591544&sr=1-1')
      assert_equal({source_url: 'https://www.amazon.co.jp/日本語の長い長い商品名/dp/B07CJ4KH1T/ref=sr_1_1?s=hobby&ie=UTF8&qid=1529591544&sr=1-1', rewrited_url: 'https://www.amazon.co.jp/dp/B07CJ4KH1T'}, @handler.debug_info[:result].first) if @handler.debug_info

      config['/amazon/affiliate'] = true
      config['/amazon/associate_tag'] = 'pooza'
      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.amazon.co.jp/日本語の長い長い商品名/dp/B07CJ4KH1T/ref=sr_1_1?s=hobby&ie=UTF8&qid=1529591544&sr=1-1')
      assert_equal({source_url: 'https://www.amazon.co.jp/日本語の長い長い商品名/dp/B07CJ4KH1T/ref=sr_1_1?s=hobby&ie=UTF8&qid=1529591544&sr=1-1', rewrited_url: 'https://www.amazon.co.jp/dp/B07CJ4KH1T?tag=pooza'}, @handler.debug_info[:result].first) if @handler.debug_info
    end
  end
end
