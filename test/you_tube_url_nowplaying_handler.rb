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
        artists: ['プリキュア公式YouTubeチャンネル'],
        title: '【キラキラ☆プリキュアアラモード】後期エンディング 「シュビドゥビ☆スイーツタイム」 （歌：宮本佳那子）',
        url: 'https://www.youtube.com/watch?v=uFfsTeExwbQ',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying \n\nhttps://www.youtube.com/watch?v=uFfsTeExwbQ\n"})
      assert_equal(@handler.debug_info[:result], [{
        artists: ['プリキュア公式YouTubeチャンネル'],
        title: '【キラキラ☆プリキュアアラモード】後期エンディング 「シュビドゥビ☆スイーツタイム」 （歌：宮本佳那子）',
        url: 'https://www.youtube.com/watch?v=uFfsTeExwbQ',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://music.youtube.com/watch?v=HjsKI-StQPU&list=RDAMVMmwJiuNq1eHY\n"})
      assert_equal(@handler.debug_info[:result], [{
        artists: ['宮本佳那子'],
        title: 'ガンバランスdeダンス ~夢みる奇跡たち~',
        url: 'https://music.youtube.com/watch?v=HjsKI-StQPU&list=RDAMVMmwJiuNq1eHY',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://music.youtube.com/watch?v=2F6yTnD1cSA&feature=share\n"})
      assert_equal(@handler.debug_info[:result], [{
        artists: ['宮本佳那子'],
        title: 'キラキラしちゃって My True Love!',
        url: 'https://music.youtube.com/watch?v=2F6yTnD1cSA&feature=share',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://music.youtube.com/watch?v=GMWIH_Hcun0&feature=share\n"})
      assert_equal(@handler.debug_info[:result], [{
        artists: ['工藤真由'],
        title: 'Tomorrow Song ~あしたのうた~',
        url: 'https://music.youtube.com/watch?v=GMWIH_Hcun0&feature=share',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://music.youtube.com/watch?v=6NaiUs4SA0k&feature=share\n"})
      assert_equal(@handler.debug_info[:result], [{
        artists: ['工藤真由'],
        title: 'プリキュアからの招待状',
        url: 'https://music.youtube.com/watch?v=6NaiUs4SA0k&feature=share',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://music.youtube.com/watch?v=vUMXlscW9Ms&feature=share\n"})
      assert_equal(@handler.debug_info[:result], [{
        artists: ['池田彩'],
        title: 'Let\'s go! スマイルプリキュア!',
        url: 'https://music.youtube.com/watch?v=vUMXlscW9Ms&feature=share',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://music.youtube.com/watch?v=-LeoA2spEwY&feature=share\n"})
      assert_equal(@handler.debug_info[:result], [{
        artists: ['キュアソード', '剣崎真琴', '宮本佳那子'],
        title: 'こころをこめて',
        url: 'https://music.youtube.com/watch?v=-LeoA2spEwY&feature=share',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://music.youtube.com/watch?v=xhV_q_kj2hU&feature=share\n"})
      assert_equal(@handler.debug_info[:result], [{
        artists: ['池田彩'],
        title: '#キボウレインボウ#',
        url: 'https://music.youtube.com/watch?v=xhV_q_kj2hU&feature=share',
      }])

      @handler.clear
      @handler.handle_pre_toot({status_field => "#nowplaying https://music.youtube.com/watch?v=aYSFvJ43-to&feature=share\n"})
      assert_equal(@handler.debug_info[:result], [{
        artists: ['牧野由依'],
        title: 'Amefuribana',
        url: 'https://music.youtube.com/watch?v=aYSFvJ43-to&feature=share',
      }])
    end
  end
end
