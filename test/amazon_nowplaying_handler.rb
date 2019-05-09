module MulukhiyaTootProxy
  class AmazonNowplayingHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('amazon_nowplaying')
    end

    def test_hook_pre_toot
      return unless AmazonService.accesskey?

      @handler.clear
      @handler.hook_pre_toot({'status' => "#nowplaying #五條真由美 ガンバランス de ダンス\n"})
      assert(@handler.result[:entries].present?)
    end
  end
end
