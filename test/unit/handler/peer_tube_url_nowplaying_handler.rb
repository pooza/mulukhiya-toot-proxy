module Mulukhiya
  class PeerTubeURLNowplayingHandlerTest < TestCase
    def setup
      @handler = Handler.create(:peer_tube_url_nowplaying)
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://fedimovie.com\n"})

      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://fedimovie.com/w/taaJ1Sh8b5JvHUZeFD1Jzk\n"})

      assert_equal(@handler.debug_info[:result], [{
        artists: Set['ぷーざ'],
        title: 'GPD Pocket 3 開封',
        url: 'https://fedimovie.com/w/taaJ1Sh8b5JvHUZeFD1Jzk',
      }])
    end
  end
end
