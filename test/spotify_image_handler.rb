module MulukhiyaTootProxy
  class SpotifyImageHandlerTest < Test::Unit::TestCase
    def setup
      return unless SpotifyService.config?
      @handler = Handler.create('spotify_image')
    end

    def test_handle_pre_toot
      return unless SpotifyService.config?
      return unless Postgres.config?
      return if @handler.disable?

      @handler.clear
      @handler.handle_pre_toot({'status' => 'https://www.spotify.com/jp/'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({'status' => 'https://open.spotify.com/track/1nRvy34z0NcTga59qOSYId'})
      assert(@handler.result[:entries].present?) if @handler.result
    end
  end
end
