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

    def test_track
      uri = SpotifyURI.parse('https://open.spotify.com')
      assert_nil(uri.track_id)
      assert_nil(uri.track)

      uri = SpotifyURI.parse('https://open.spotify.com/track/7f47OJZ6x9EZ4G2ZWOOlQZ')
      assert_equal(uri.track_id, '7f47OJZ6x9EZ4G2ZWOOlQZ')
      assert_kind_of(RSpotify::Track, uri.track)

      uri = SpotifyURI.parse('https://open.spotify.com/album/7xtiD9nNWrbbAtbbInNllD')
      assert_nil(uri.track_id)
      assert_nil(uri.track)
    end

    def test_album
      uri = SpotifyURI.parse('https://open.spotify.com')
      assert_nil(uri.album_id)
      assert_nil(uri.album)

      uri = SpotifyURI.parse('https://open.spotify.com/track/7f47OJZ6x9EZ4G2ZWOOlQZ')
      assert_nil(uri.album_id)
      assert_kind_of(RSpotify::Album, uri.album)

      uri = SpotifyURI.parse('https://open.spotify.com/album/7xtiD9nNWrbbAtbbInNllD')
      assert_equal(uri.album_id, '7xtiD9nNWrbbAtbbInNllD')
      assert_kind_of(RSpotify::Album, uri.album)
    end

    def test_image_uri
      uri = SpotifyURI.parse('https://open.spotify.com')
      assert_nil(uri.image_uri)

      uri = SpotifyURI.parse('https://open.spotify.com/track/2j7bBkmzkl2Yz6oAsHozX0')
      assert_kind_of(Ginseng::URI, uri.image_uri)
    end
  end
end
