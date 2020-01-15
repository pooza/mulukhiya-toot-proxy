module Mulukhiya
  class SpotifyURLNowplayingHandlerTest < TestCase
    def setup
      @handler = Handler.create('spotify_url_nowplaying')
    end

    def test_handle_pre_toot
      return unless handler?

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://open.spotify.com/\n"})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://open.spotify.com/track/0nfc11o6frUdWKgG51OVFS\n"})
      assert_equal(@handler.result[:entries], ['https://open.spotify.com/track/0nfc11o6frUdWKgG51OVFS'])
    end
  end
end
