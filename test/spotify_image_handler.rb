module MulukhiyaTootProxy
  class SpotifyImageHandlerTest < Test::Unit::TestCase
    def test_exec
      config = Config.instance

      handler = Handler.create('spotify_image')
      handler.mastodon = Mastodon.new(config['/instance_url'], config['/test/token'])

      handler.exec({'status' => 'https://open.spotify.com/track/1nRvy34z0NcTga59qOSYId'})
      assert_equal(handler.summary, 'SpotifyImageHandler,1')

      handler.exec({'status' => 'https://www.spotify.com/jp/'})
      assert_equal(handler.summary, 'SpotifyImageHandler,1')
    end
  end
end
