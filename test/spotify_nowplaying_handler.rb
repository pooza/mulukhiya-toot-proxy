module Mulukhiya
  class SpotifyNowplayingHandlerTest < TestCase
    def setup
      @config = Config.instance
      @handler = Handler.create('spotify_nowplaying')
    end

    def test_handle_pre_toot
      return unless handler?
      @handler.handle_pre_toot(status_field => "#nowplaying エビカニクス\n")
      assert_equal(@handler.result[:entries], ['エビカニクス'])
    end
  end
end
