module MulukhiyaTootProxy
  class AmazonNowplayingHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('amazon_nowplaying')
    end

    def test_exec
      return unless AmazonService.accesskey?

      @handler.clear
      @handler.exec({'status' => "#nowplaying #五條真由美 ガンバランス de ダンス\n"})
      assert(@handler.result[:entries].present?)
    end
  end
end
