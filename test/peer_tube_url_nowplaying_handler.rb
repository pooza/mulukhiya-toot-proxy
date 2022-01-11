module Mulukhiya
  class PeerTubeURLNowplayingHandlerTest < TestCase
    def setup
      @handler = Handler.create('peer_tube_url_nowplaying')
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://fedimovie.com\n"})
      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://fedimovie.com/api/v1/videos/iKu2ASqiBm796yuzqdx9Zt\n"})
      assert_equal(@handler.debug_info[:result], [{
        artists: Set['鴉河雛@PeerTube'],
        title: '[LIVE] DJMAXをただやるだけ。',
        url: 'https://fedimovie.com/api/v1/videos/iKu2ASqiBm796yuzqdx9Zt',
      }])
    end
  end
end
