module MulukhiyaTootProxy
  class SpotifyImageHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('spotify_image')
    end

    def test_handle_pre_toot
      return if Environment.ci?

      @handler.clear
      @handler.handle_pre_toot({'status' => 'https://www.spotify.com/jp/'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({'status' => 'https://open.spotify.com/track/1nRvy34z0NcTga59qOSYId'})
      assert(@handler.result[:entries].present?)
    end
  end
end
