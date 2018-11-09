module MulukhiyaTootProxy
  class SpotifyUrlNowplayingHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = Handler.create('spotify_url_nowplaying')
      handler.exec({'status' => "#nowplaying https://open.spotify.com/\n"})
      assert_equal(handler.result, 'SpotifyUrlNowplayingHandler,0')

      handler.exec({'status' => "#nowplaying https://open.spotify.com/track/0nfc11o6frUdWKgG51OVFS\n"})
      assert_equal(handler.result, 'SpotifyUrlNowplayingHandler,1')
    end
  end
end
