module Mulukhiya
  class AmazonURLNowplayingHandlerTest < TestCase
    def setup
      @handler = Handler.create('amazon_url_nowplaying')
    end

    def test_handle_pre_toot
      return unless handler?

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://www.amazon.co.jp/\n"})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://www.amazon.co.jp/dp/B00QIUDCXS\n"})
      assert_equal(@handler.result[:entries], ['https://www.amazon.co.jp/dp/B00QIUDCXS'])
    end
  end
end
