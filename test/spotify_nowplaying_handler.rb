module Mulukhiya
  class SpotifyNowplayingHandlerTest < TestCase
    def setup
      @handler = Handler.create('spotify_nowplaying')
    end

    def test_handle_pre_toot
      return unless handler?
      @handler.handle_pre_toot(status_field => "#nowplaying https://open.spotify.com/track/4Qeq365hoRsgQYYNpl5sVs?si=ZR4Cn7bBTVWjtpHL9-Smcw\n")
      assert_nil(@handler.debug_info)

      return unless handler?
      @handler.handle_pre_toot(status_field => "#nowplaying エビカニクス\n")
      assert_equal(@handler.debug_info[:result], [{keyword: 'エビカニクス'}])
    end
  end
end
