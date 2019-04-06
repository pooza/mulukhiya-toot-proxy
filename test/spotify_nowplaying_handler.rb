module MulukhiyaTootProxy
  class SpotifyNowplayingHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = Handler.create('spotify_nowplaying')
      handler.exec({'status' => "#nowplaying #五條真由美 ガンバランス de ダンス\n"})
      assert_equal(handler.summary, 'SpotifyNowplayingHandler,1')
    end
  end
end
