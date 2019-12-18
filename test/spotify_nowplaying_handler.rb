module MulukhiyaTootProxy
  class SpotifyNowplayingHandlerTest < TestCase
    def setup
      @config = Config.instance
      @handler = Handler.create('spotify_nowplaying')
    end

    def test_handle_pre_toot
      return if invalid_handler?
      @handler.handle_pre_toot({message_field => "#nowplaying #五條真由美 ガンバランス de ダンス\n"})
      assert_equal(@handler.result[:entries], ['#五條真由美 ガンバランス de ダンス'])
    end
  end
end
