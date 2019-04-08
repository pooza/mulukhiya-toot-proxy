module MulukhiyaTootProxy
  class SpotifyNowplayingHandlerTest < Test::Unit::TestCase
    def setup
      @config = Config.instance
      @handler = Handler.create('spotify_nowplaying')
    end

    def test_exec
      @handler.exec({'status' => "#nowplaying #五條真由美 ガンバランス de ダンス\n"})
      assert_equal(@handler.result[:entries], ['#五條真由美 ガンバランス de ダンス'])
    end
  end
end
