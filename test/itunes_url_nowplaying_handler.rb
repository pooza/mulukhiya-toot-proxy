module Mulukhiya
  class ItunesURLNowplayingHandlerTest < TestCase
    def setup
      @handler = Handler.create('itunes_url_nowplaying')
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot(status_field => "#nowplaying https://music.apple.com\n")
      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot(status_field => "#nowplaying https://music.apple.com/jp/album/hug%E3%81%A3%E3%81%A8-%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2-%E4%B8%BB%E9%A1%8C%E6%AD%8C%E3%82%B7%E3%83%B3%E3%82%B0%E3%83%AB-%E9%80%9A%E5%B8%B8%E7%9B%A4-op-we-can-hug%E3%81%A3%E3%81%A8-%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2-ed-hug%E3%81%A3%E3%81%A8/1369123162?i=1369123174\n")
      assert_equal(@handler.debug_info[:result], [{
        url: 'https://music.apple.com/jp/album/hug%E3%81%A3%E3%81%A8-%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2-%E4%B8%BB%E9%A1%8C%E6%AD%8C%E3%82%B7%E3%83%B3%E3%82%B0%E3%83%AB-%E9%80%9A%E5%B8%B8%E7%9B%A4-op-we-can-hug%E3%81%A3%E3%81%A8-%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2-ed-hug%E3%81%A3%E3%81%A8/1369123162?i=1369123174',
        artist: '宮本佳那子',
      }])

      @handler.clear
      @handler.handle_pre_toot(status_field => "#nowplaying https://music.apple.com/jp/album/hug%E3%81%A3%E3%81%A8-%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2-%E4%B8%BB%E9%A1%8C%E6%AD%8C%E3%82%B7%E3%83%B3%E3%82%B0%E3%83%AB-%E9%80%9A%E5%B8%B8%E7%9B%A4-op-we-can-hug%E3%81%A3%E3%81%A8-%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2-ed-hug%E3%81%A3%E3%81%A8/1369123162\n")
      assert_equal(@handler.debug_info[:result], [{
        url: 'https://music.apple.com/jp/album/hug%E3%81%A3%E3%81%A8-%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2-%E4%B8%BB%E9%A1%8C%E6%AD%8C%E3%82%B7%E3%83%B3%E3%82%B0%E3%83%AB-%E9%80%9A%E5%B8%B8%E7%9B%A4-op-we-can-hug%E3%81%A3%E3%81%A8-%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2-ed-hug%E3%81%A3%E3%81%A8/1369123162',
        artist: 'Various Artists',
      }])
    end

    def test_push
      @handler.clear
      body = @handler.handle_pre_toot(status_field => "シュビドゥビ☆スイーツタイム\n#nowplaying https://music.apple.com/jp/album//1352845788?i=1352845804\n")[status_field]
      lines = body.each_line.to_a.map(&:chomp)
      assert(lines.member?('シュビドゥビ☆スイーツタイム'))
      assert(lines.member?('宮本佳那子'))
    end
  end
end
