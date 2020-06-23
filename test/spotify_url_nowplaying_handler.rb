module Mulukhiya
  class SpotifyURLNowplayingHandlerTest < TestCase
    def setup
      @handler = Handler.create('spotify_url_nowplaying')
    end

    def test_handle_pre_toot
      return unless handler?

      @handler.clear
      @handler.handle_pre_toot(status_field => "#nowplaying https://open.spotify.com/\n")
      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot(status_field => "#nowplaying https://open.spotify.com/track/2oBorZqiVTpXAD8h7DCYWZ\n")
      assert_equal(@handler.debug_info[:result], [{url: 'https://open.spotify.com/track/2oBorZqiVTpXAD8h7DCYWZ'}])
    end
  end
end
