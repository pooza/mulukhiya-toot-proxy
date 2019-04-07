module MulukhiyaTootProxy
  class SpotifyImageHandlerTest < Test::Unit::TestCase
    def setup
      config = Config.instance
      @handler = Handler.create('spotify_image')
      @handler.mastodon = Mastodon.new(config['/instance_url'], config['/test/token'])
    end

    def test_exec
      @handler.exec({'status' => 'https://www.spotify.com/jp/'})
      assert_nil(@handler.result)

      @handler.exec({'status' => 'https://open.spotify.com/track/1nRvy34z0NcTga59qOSYId'})
      assert_equal(@handler.result[:entries].count, 1)
    end
  end
end
