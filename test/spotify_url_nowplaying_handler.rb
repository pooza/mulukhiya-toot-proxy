module MulukhiyaTootProxy
  class SpotifyURLNowplayingHandlerTest < Test::Unit::TestCase
    def setup
      return if Environment.ci?
      @handler = Handler.create('spotify_url_nowplaying')
    end

    def test_handle_pre_toot
      return if Environment.ci?
      return if @handler.disable?

      @handler.clear
      @handler.handle_pre_toot({'status' => "#nowplaying https://open.spotify.com/\n"})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({'status' => "#nowplaying https://open.spotify.com/track/0nfc11o6frUdWKgG51OVFS\n"})
      assert_equal(@handler.result[:entries], ['https://open.spotify.com/track/0nfc11o6frUdWKgG51OVFS'])
    end
  end
end
