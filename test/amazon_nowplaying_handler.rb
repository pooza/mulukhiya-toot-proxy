require 'mulukhiya/handler/amazon_nowplaying'

module MulukhiyaTootProxy
  class AmazonNowplayingHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = AmazonNowplayingHandler.new
      handler.exec({'status' => "#nowplaying #五條真由美 ガンバランス de ダンス\n"})
      assert_equal(handler.result, 'AmazonNowplayingHandler,1')
    end
  end
end
