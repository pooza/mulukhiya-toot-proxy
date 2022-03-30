module Mulukhiya
  class AmazonURLNowplayingHandlerTest < TestCase
    def setup
      @handler = Handler.create('amazon_url_nowplaying')
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot(status_field => "#nowplaying https://www.amazon.co.jp/\n")
      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot(status_field => "#nowplaying https://www.amazon.co.jp/dp/B00QIUDCXS\n")
      assert_equal([{url: 'https://www.amazon.co.jp/dp/B00QIUDCXS'}], @handler.debug_info[:result]) if @handler.debug_info[:result].present?
    end
  end
end
