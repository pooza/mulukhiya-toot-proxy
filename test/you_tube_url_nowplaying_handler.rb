module MulukhiyaTootProxy
  class YouTubeURLNowplayingHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('you_tube_url_nowplaying')
    end

    def test_exec
      @handler.clear
      @handler.exec({'status' => "#nowplaying https://www.youtube.com\n"})
      assert_nil(@handler.result)

      @handler.clear
      @handler.exec({'status' => "#nowplaying https://www.youtube.com/watch?v=uFfsTeExwbQ\n"})
      assert_equal(@handler.result[:entries], ['https://www.youtube.com/watch?v=uFfsTeExwbQ'])

      @handler.clear
      @handler.exec({'status' => "#nowplaying \n\nhttps://www.youtube.com/watch?v=uFfsTeExwbQ\n"})
      assert_equal(@handler.result[:entries], ['https://www.youtube.com/watch?v=uFfsTeExwbQ'])
    end
  end
end
