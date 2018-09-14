require 'mulukhiya/handler/spotify_nowplaying'

module MulukhiyaTootProxy
  class SpotifyNowplayingHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = SpotifyNowplayingHandler.new
      handler.exec({'status' => "#nowplaying #五條真由美 ガンバランス de ダンス\n"})
      assert_equal(handler.result, 'SpotifyNowplayingHandler,1')
    end
  end
end
