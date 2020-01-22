module Mulukhiya
  class SpotifyImageHandlerTest < TestCase
    def setup
      @handler = Handler.create('spotify_image')
    end

    def test_handle_pre_toot
      return unless handler?

      @handler.clear
      @handler.handle_pre_toot({status_field => 'https://www.spotify.com/jp/'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({status_field => 'https://open.spotify.com/track/7iNq9x3bom8XKfZsJWuWVH'})
      assert(@handler.result[:entries].present?) if @handler.result
    end
  end
end
