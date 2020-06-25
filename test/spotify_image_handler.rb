module Mulukhiya
  class SpotifyImageHandlerTest < TestCase
    def setup
      @handler = Handler.create('spotify_image')
    end

    def test_handle_pre_toot
      return unless handler?

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.spotify.com/jp/')
      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://open.spotify.com/track/7iNq9x3bom8XKfZsJWuWVH')
      assert(@handler.debug_info[:result].present?) if @handler.debug_info
    end
  end
end
