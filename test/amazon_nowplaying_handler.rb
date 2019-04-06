module MulukhiyaTootProxy
  class AmazonNowplayingHandlerTest < Test::Unit::TestCase
    def test_exec
      return unless AmazonService.accesskey?
      handler = Handler.create('amazon_nowplaying')
      handler.exec({'status' => "#nowplaying #五條真由美 ガンバランス de ダンス\n"})
      assert_equal(handler.summary, 'AmazonNowplayingHandler,1')
    end
  end
end
