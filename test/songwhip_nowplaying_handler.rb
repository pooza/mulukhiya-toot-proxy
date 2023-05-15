module Mulukhiya
  class SongwhipNowplayingHandlerTest < TestCase
    def setup
      @handler = Handler.create(:songwhip_nowplaying)
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot(status_field => "#nowplaying https://open.spotify.com/track/4P68anZPOiBfJj8IFzGhSV\n")

      if @handler.debug_info[:errors].present?
        assert_equal([{
          class: 'Ginseng::GatewayError',
          message: 'Bad response 429',
        }], @handler.debug_info[:errors].except(class:, message:))
      else
        assert_equal([{
          source_url: 'https://open.spotify.com/track/4P68anZPOiBfJj8IFzGhSV',
          songwhip_url: 'https://songwhip.com/mayumigojo/%E3%82%AC%E3%83%B3%E3%83%90%E3%83%A9%E3%83%B3%E3%82%B9de%E3%83%80%E3%83%B3%E3%82%B9',
        }], @handler.debug_info[:result])
      end

      @handler.clear
      @handler.handle_pre_toot(status_field => "#nowplaying https://music.apple.com/jp/album/405905341?i=405905342&uo=4\n")

      if @handler.debug_info[:errors].present?
        assert_equal([{
          class: 'Ginseng::GatewayError',
          message: 'Bad response 429',
        }], @handler.debug_info[:errors].except(class:, message:))
      else
        assert_equal([{
          source_url: 'https://music.apple.com/jp/album/405905341?i=405905342&uo=4',
          songwhip_url: 'https://songwhip.com/kanakomiyamoto/ganbalance-de-dance-yumemiru-kiseki-tachi',
        }], @handler.debug_info[:result])
      end

      @handler.clear
      @handler.handle_pre_toot(status_field => "色々PC持ってるけど、\nWindows\nWindows\nWindows\nWindows\nUbuntu\nFedora\nChromeOS\nChromeOS\n\nmacOSはない。")

      assert_equal(
        @handler.payload,
        {status_field => "色々PC持ってるけど、\nWindows\nWindows\nWindows\nWindows\nUbuntu\nFedora\nChromeOS\nChromeOS\n\nmacOSはない。"},
      )
    end
  end
end
