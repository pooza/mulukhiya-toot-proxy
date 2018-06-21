require 'mulukhiya-toot-proxy/handler/amazon_asin'

module MulukhiyaTootProxy
  class AmazonAsinHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = AmazonAsinHandler.new
      assert_equal(handler.exec('https://www.amazon.co.jp/HUG%E3%81%A3%E3%81%A8-%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2-%E3%82%AD%E3%83%A5%E3%83%BC%E3%83%86%E3%82%A3%E3%83%BC%E3%83%95%E3%82%A3%E3%82%AE%E3%83%A5%E3%82%A23-SpecialSet-1%E3%82%BB%E3%83%83%E3%83%88%E5%85%A5%E3%82%8A/dp/B07CJ4KH1T/ref=sr_1_1?s=hobby&ie=UTF8&qid=1529591544&sr=1-1&keywords=%28%E4%BB%AE%29+HUG%E3%81%A3%E3%81%A8%21%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2+%E3%82%AD%E3%83%A5%E3%83%BC%E3%83%86%E3%82%A3%E3%83%BC%E3%83%95%E3%82%A3%E3%82%AE%E3%83%A5%E3%82%A23+SpecialSet+%281%E3%82%BB%E3%83%83%E3%83%88%E5%85%A5%E3%82%8A%29+%E9%A3%9F%E7%8E%A9%E3%83%BB%E3%82%AC%E3%83%A0+%28HUG%E3%81%A3%E3%81%A8%21%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2%29'), 'https://www.amazon.co.jp/dp/B07CJ4KH1T')
      assert_equal(handler.result, 'AmazonAsinHandler,1')
    end
  end
end
