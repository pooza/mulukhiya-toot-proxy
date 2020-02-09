module Mulukhiya
  class AmazonNowplayingHandlerTest < TestCase
    def setup
      @handler = Handler.create('amazon_nowplaying')
    end

    def test_handle_pre_toot
      return unless handler?
      @handler.handle_pre_toot(status_field => "#nowplaying #五條真由美 ガンバランス de ダンス\n")
      assert(@handler.result[:entries].present?)
    end
  end
end
