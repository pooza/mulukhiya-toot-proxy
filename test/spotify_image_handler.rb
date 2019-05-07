module MulukhiyaTootProxy
  class SpotifyImageHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('spotify_image')
    end

    def test_exec
      @handler.exec({'status' => 'https://www.spotify.com/jp/'})
      assert_nil(@handler.result)

      @handler.exec({'status' => 'https://open.spotify.com/track/1nRvy34z0NcTga59qOSYId'})
      assert_equal(@handler.result[:entries].count, 1)
    end
  end
end
