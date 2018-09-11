require 'mulukhiya/handler/spotify_nowplaying'

module MulukhiyaTootProxy
  class SpotifyNowplayingHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = SpotifyNowplayingHandler.new
      assert_equal(handler.exec({'status' => "#nowplaying #五條真由美 ガンバランス de ダンス\n"})['status'], "#nowplaying #五條真由美 ガンバランス de ダンス\nhttps://open.spotify.com/track/0x970Bre8Q1NuuzROmFqKU")
      assert_equal(handler.result, 'SpotifyNowplayingHandler,1')
    end
  end
end
