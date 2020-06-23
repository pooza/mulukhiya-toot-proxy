module Mulukhiya
  class YouTubeURLNowplayingHandlerTest < TestCase
    def setup
      @handler = Handler.create('you_tube_url_nowplaying')
    end

    def test_handle_pre_toot
      return unless handler?

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://www.youtube.com\n"})
      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://www.youtube.com/watch?v=uFfsTeExwbQ\n"})
      assert_equal(@handler.debug_info[:result], [{
        channel: 'プリキュア公式YouTubeチャンネル',
        url: 'https://www.youtube.com/watch?v=uFfsTeExwbQ',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying \n\nhttps://www.youtube.com/watch?v=uFfsTeExwbQ\n"})
      assert_equal(@handler.debug_info[:result], [{
        channel: 'プリキュア公式YouTubeチャンネル',
        url: 'https://www.youtube.com/watch?v=uFfsTeExwbQ',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://music.youtube.com/watch?v=HjsKI-StQPU&list=RDAMVMmwJiuNq1eHY\n"})
      assert_equal(@handler.debug_info[:result], [{
        artist: 'Kanako Miyamoto',
        url: 'https://music.youtube.com/watch?v=HjsKI-StQPU&list=RDAMVMmwJiuNq1eHY',
      }])
    end
  end
end
