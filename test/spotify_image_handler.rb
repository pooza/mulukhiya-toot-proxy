require 'mulukhiya/handler/spotify_image'
require 'mulukhiya/mastodon'
require 'mulukhiya/config'

module MulukhiyaTootProxy
  class SpotifyImageHandlerTest < Test::Unit::TestCase
    def test_exec
      config = Config.instance
      return unless config['local']['spotify']

      handler = SpotifyImageHandler.new
      handler.mastodon = Mastodon.new(
        config['local']['instance_url'],
        config['local']['test']['token'],
      )

      handler.exec({'status' => 'https://open.spotify.com/track/1nRvy34z0NcTga59qOSYId'})
      assert_equal(handler.result, 'SpotifyImageHandler,1')

      handler.exec({'status' => 'https://www.spotify.com/jp/'})
      assert_equal(handler.result, 'SpotifyImageHandler,1')
    end
  end
end
