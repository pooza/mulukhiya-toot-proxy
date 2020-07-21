module Mulukhiya
  class SpotifyURITest < TestCase
    def setup
      @config = Config.instance
    end

    def test_spotify?
      uri = SpotifyURI.parse('https://google.com')
      assert_false(uri.spotify?)

      uri = SpotifyURI.parse('https://spotify.com')
      assert(uri.spotify?)

      uri = SpotifyURI.parse('https://open.spotify.com')
      assert(uri.spotify?)
    end

    def test_track_id
      uri = SpotifyURI.parse('https://open.spotify.com')
      assert_nil(uri.track_id)

      uri = SpotifyURI.parse('https://open.spotify.com/track/hogehogeh')
      assert_equal(uri.track_id, 'hogehogeh')

      uri = SpotifyURI.parse('https://open.spotify.com/album/fugafuga')
      assert_nil(uri.track_id)
    end

    def test_album_id
      uri = SpotifyURI.parse('https://open.spotify.com')
      assert_nil(uri.album_id)

      uri = SpotifyURI.parse('https://open.spotify.com/track/hogehogeh')
      assert_nil(uri.album_id)

      uri = SpotifyURI.parse('https://open.spotify.com/album/fugafuga')
      assert_equal(uri.album_id, 'fugafuga')
    end

    def test_image_uri
      uri = SpotifyURI.parse('https://open.spotify.com')
      assert_nil(uri.image_uri)

      uri = SpotifyURI.parse('https://open.spotify.com/track/2j7bBkmzkl2Yz6oAsHozX0')
      assert_kind_of(Ginseng::URI, uri.image_uri)
    end
  end
end
