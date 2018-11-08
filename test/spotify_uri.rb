module MulukhiyaTootProxy
  class SpotifyUriTest < Test::Unit::TestCase
    def test_spotify?
      uri = SpotifyUri.parse('https://google.com')
      assert_false(uri.spotify?)

      uri = SpotifyUri.parse('https://spotify.com')
      assert_true(uri.spotify?)

      uri = SpotifyUri.parse('https://open.spotify.com')
      assert_true(uri.spotify?)
    end

    def test_track_id
      uri = SpotifyUri.parse('https://open.spotify.com')
      assert_nil(uri.track_id)

      uri = SpotifyUri.parse('https://open.spotify.com/track/hogehogeh')
      assert_equal(uri.track_id, 'hogehogeh')
    end

    def test_image_uri
      uri = SpotifyUri.parse('https://open.spotify.com')
      assert_nil(uri.image_uri)

      uri = SpotifyUri.parse('https://open.spotify.com/track/2j7bBkmzkl2Yz6oAsHozX0')
      assert_true(uri.image_uri.is_a?(Addressable::URI))
    end
  end
end
