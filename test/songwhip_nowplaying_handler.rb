module Mulukhiya
  class SongwhipNowplayingHandlerTest < TestCase
    def setup
      @handler = Handler.create('songwhip_nowplaying')
    end

    def test_handle_pre_toot
      return unless handler?

      @handler.clear
      @handler.handle_pre_toot(status_field => "#nowplaying https://open.spotify.com/\n")
      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot(status_field => "#nowplaying https://open.spotify.com/track/4P68anZPOiBfJj8IFzGhSV\n")
      assert_equal(@handler.debug_info[:result], [{
        source_url: 'https://open.spotify.com/track/4P68anZPOiBfJj8IFzGhSV',
        alt_url: 'https://songwhip.com/mayumigojo/%E3%82%AC%E3%83%B3%E3%83%90%E3%83%A9%E3%83%B3%E3%82%B9de%E3%83%80%E3%83%B3%E3%82%B9',
      }])

      @handler.clear
      @handler.handle_pre_toot(status_field => "#nowplaying https://music.apple.com/jp/album/405905341?i=405905342&uo=4\n")
      assert_equal(@handler.debug_info[:result], [{
        source_url: 'https://music.apple.com/jp/album/405905341?i=405905342&uo=4',
        alt_url: 'https://songwhip.com/%E5%AE%AE%E6%9C%AC%E4%BD%B3%E9%82%A3%E5%AD%90/%E3%82%AC%E3%83%B3%E3%83%90%E3%83%A9%E3%83%B3%E3%82%B9de%E3%83%80%E3%83%B3%E3%82%B9-%E5%A4%A2%E3%81%BF%E3%82%8B%E5%A5%87%E8%B7%A1%E3%81%9F%E3%81%A1',
      }])
    end
  end
end
