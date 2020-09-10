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
        artist: 'プリキュア公式YouTubeチャンネル',
        url: 'https://www.youtube.com/watch?v=uFfsTeExwbQ',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying \n\nhttps://www.youtube.com/watch?v=uFfsTeExwbQ\n"})
      assert_equal(@handler.debug_info[:result], [{
        artist: 'プリキュア公式YouTubeチャンネル',
        url: 'https://www.youtube.com/watch?v=uFfsTeExwbQ',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://music.youtube.com/watch?v=HjsKI-StQPU&list=RDAMVMmwJiuNq1eHY\n"})
      assert_equal(@handler.debug_info[:result], [{
        artist: '宮本佳那子',
        url: 'https://music.youtube.com/watch?v=HjsKI-StQPU&list=RDAMVMmwJiuNq1eHY',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://music.youtube.com/watch?v=2F6yTnD1cSA&feature=share\n"})
      assert_equal(@handler.debug_info[:result], [{
        artist: '宮本佳那子',
        url: 'https://music.youtube.com/watch?v=2F6yTnD1cSA&feature=share',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://music.youtube.com/watch?v=GMWIH_Hcun0&feature=share\n"})
      assert_equal(@handler.debug_info[:result], [{
        artist: '工藤真由',
        url: 'https://music.youtube.com/watch?v=GMWIH_Hcun0&feature=share',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://music.youtube.com/watch?v=6NaiUs4SA0k&feature=share\n"})
      assert_equal(@handler.debug_info[:result], [{
        artist: '工藤真由',
        url: 'https://music.youtube.com/watch?v=6NaiUs4SA0k&feature=share',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://music.youtube.com/watch?v=vUMXlscW9Ms&feature=share\n"})
      assert_equal(@handler.debug_info[:result], [{
        artist: '池田彩',
        url: 'https://music.youtube.com/watch?v=vUMXlscW9Ms&feature=share',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://music.youtube.com/watch?v=-LeoA2spEwY&feature=share\n"})
      assert_equal(@handler.debug_info[:result], [{
        artist: 'キュアソード/剣崎真琴(CV:宮本佳那子)',
        url: 'https://music.youtube.com/watch?v=-LeoA2spEwY&feature=share',
      }])
    end
  end
end
