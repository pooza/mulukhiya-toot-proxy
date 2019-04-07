module MulukhiyaTootProxy
  class SpotifyURLNowplayingHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('spotify_url_nowplaying')
    end


    def test_exec
      @handler.exec({'status' => "#nowplaying https://open.spotify.com/\n"})
      assert_nil(@handler.result)

      @handler.exec({'status' => "#nowplaying https://open.spotify.com/track/0nfc11o6frUdWKgG51OVFS\n"})
      assert_equal(@handler.result[:entries], ['https://open.spotify.com/track/0nfc11o6frUdWKgG51OVFS'])
    end
  end
end
