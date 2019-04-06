module MulukhiyaTootProxy
  class YouTubeURLNowplayingHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = Handler.create('you_tube_url_nowplaying')

      handler.exec({'status' => "#nowplaying https://www.youtube.com\n"})
      assert_equal(handler.summary, 'YouTubeURLNowplayingHandler,0')

      handler.exec({'status' => "#nowplaying https://www.youtube.com/watch?v=uFfsTeExwbQ\n"})
      assert_equal(handler.summary, 'YouTubeURLNowplayingHandler,1')
    end
  end
end
