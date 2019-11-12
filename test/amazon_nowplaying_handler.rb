module MulukhiyaTootProxy
  class AmazonNowplayingHandlerTest < Test::Unit::TestCase
    def setup
      return unless AmazonService.config?
      @handler = Handler.create('amazon_nowplaying')
    end

    def test_handle_pre_toot
      return unless AmazonService.config?
      return if @handler.disable?

      @handler.clear
      @handler.handle_pre_toot({'status' => "#nowplaying #五條真由美 ガンバランス de ダンス\n"})
      assert(@handler.result[:entries].present?)
    end
  end
end
