module Mulukhiya
  class ItunesURLHandlerTest < TestCase
    def setup
      @handler = Handler.create(:itunes_url)
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://music.apple.com/')

      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://music.apple.com/jp/album/%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A25-%E3%83%95%E3%83%AB-%E3%82%B9%E3%83%AD%E3%83%83%E3%83%88%E3%83%AB-go-go/398139262?i=398139273&uo=4')

      assert_equal({rewrited_url: 'https://music.apple.com/jp/album/398139262?i=398139273&uo=4', source_url: 'https://music.apple.com/jp/album/%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A25-%E3%83%95%E3%83%AB-%E3%82%B9%E3%83%AD%E3%83%83%E3%83%88%E3%83%AB-go-go/398139262?i=398139273&uo=4'}, @handler.debug_info[:result].first)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://music.apple.com/jp/song/%E7%AC%91%E9%A1%94%E3%81%AE%E3%83%A6%E3%83%8B%E3%82%BE%E3%83%B3/1789469289')

      assert_equal({rewrited_url: 'https://music.apple.com/jp/song/1789469289', source_url: 'https://music.apple.com/jp/song/%E7%AC%91%E9%A1%94%E3%81%AE%E3%83%A6%E3%83%8B%E3%82%BE%E3%83%B3/1789469289'}, @handler.debug_info[:result].first)

      # MV の URL（#4897）。`?uo=4` も落とす。
      mv = 'https://music.apple.com/jp/music-video/%E3%81%AD%E3%81%93%E3%81%96%E3%81%8B%E3%81%AA%E3%83%80%E3%83%B3%E3%82%B7%E3%83%B3%E3%82%B0/1312882764?uo=4'
      @handler.clear
      @handler.handle_pre_toot(status_field => mv)

      assert_equal({rewrited_url: 'https://music.apple.com/jp/music-video/1312882764', source_url: mv}, @handler.debug_info[:result].first)
    end
  end
end
