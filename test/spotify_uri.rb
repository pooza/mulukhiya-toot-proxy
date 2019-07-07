module MulukhiyaTootProxy
  class SpotifyURITest < Test::Unit::TestCase
    def setup
      return if Environment.ci?
      @config = Config.instance
    end

    def test_spotify?
      return if Environment.ci?

      uri = SpotifyURI.parse('https://google.com')
      assert_false(uri.spotify?)

      uri = SpotifyURI.parse('https://spotify.com')
      assert(uri.spotify?)

      uri = SpotifyURI.parse('https://open.spotify.com')
      assert(uri.spotify?)
    end

    def test_track_id
      return if Environment.ci?

      uri = SpotifyURI.parse('https://open.spotify.com')
      assert_nil(uri.track_id)

      uri = SpotifyURI.parse('https://open.spotify.com/track/hogehogeh')
      assert_equal(uri.track_id, 'hogehogeh')
    end

    def test_image_uri
      return if Environment.ci?

      uri = SpotifyURI.parse('https://open.spotify.com')
      assert_nil(uri.image_uri)

      uri = SpotifyURI.parse('https://open.spotify.com/track/2j7bBkmzkl2Yz6oAsHozX0')
      assert(uri.image_uri.is_a?(Ginseng::URI))
    end
  end
end
