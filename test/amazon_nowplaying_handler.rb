module MulukhiyaTootProxy
  class AmazonNowplayingHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('amazon_nowplaying')
    end

    def test_exec
      return unless AmazonService.accesskey?
      @handler.exec({'status' => "#nowplaying #五條真由美 ガンバランス de ダンス\n"})
      assert_equal(@handler.result[:entries].count, 1)
    end
  end
end
