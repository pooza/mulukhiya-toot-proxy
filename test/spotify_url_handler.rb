module Mulukhiya
  class SpotifyURLHandlerTest < TestCase
    def setup
      @handler = Handler.create('spotify_url')
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://link.tospotify.com/ZArOrV7KAbb')
      assert_equal(@handler.debug_info[:result].first, rewrited_url: 'https://open.spotify.com/track/3L6K6hTLVjVhiTdsMEaWii', source_url: 'https://link.tospotify.com/ZArOrV7KAbb')
    end
  end
end
