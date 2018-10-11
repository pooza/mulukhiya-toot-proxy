require 'mulukhiya/handler/itunes_nowplaying'

module MulukhiyaTootProxy
  class ItunesNowplayingHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = ItunesNowplayingHandler.new
      handler.exec({'status' => "#nowplaying #五條真由美 ガンバランス de ダンス\n"})
      assert_equal(handler.result, 'ItunesNowplayingHandler,1')
    end
  end
end
