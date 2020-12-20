module Mulukhiya
  class SpotifyURITest < TestCase
    def test_spotify?
      uri = SpotifyURI.parse('https://google.com')
      assert_false(uri.spotify?)

      uri = SpotifyURI.parse('https://spotify.com')
      assert(uri.spotify?)

      uri = SpotifyURI.parse('https://open.spotify.com')
      assert(uri.spotify?)

      uri = SpotifyURI.parse('https://link.tospotify.com/ZArOrV7KAbb')
      assert_false(uri.spotify?)
    end

    def test_shortenable?
      uri = SpotifyURI.parse('https://google.com')
      assert_false(uri.shortenable?)

      uri = SpotifyURI.parse('https://spotify.com')
      assert_false(uri.shortenable?)

      uri = SpotifyURI.parse('https://link.tospotify.com/ZArOrV7KAbb')
      assert(uri.shortenable?)
    end

    def test_shorten
      uri = SpotifyURI.parse('https://google.com')
      assert_nil(uri.shorten)

      uri = SpotifyURI.parse('https://spotify.com')
      assert_nil(uri.shorten)

      uri = SpotifyURI.parse('https://link.tospotify.com/ZArOrV7KAbb')
      assert_equal(uri.shorten.to_s, 'https://open.spotify.com/track/3L6K6hTLVjVhiTdsMEaWii')
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

    def test_title
      uri = SpotifyURI.parse('https://open.spotify.com')
      assert_nil(uri.title)

      uri = SpotifyURI.parse('https://open.spotify.com/track/7f47OJZ6x9EZ4G2ZWOOlQZ')
      assert_equal(uri.title, 'ガンバランスdeダンス ~夢みる奇跡たち~')

      uri = SpotifyURI.parse('https://open.spotify.com/album/7xtiD9nNWrbbAtbbInNllD')
      assert_equal(uri.title, 'Yes! プリキュア5 ボーカルベスト!! 【Yes! プリキュア5】')
    end

    def test_album_name
      uri = SpotifyURI.parse('https://open.spotify.com')
      assert_nil(uri.album_name)

      uri = SpotifyURI.parse('https://open.spotify.com/track/7f47OJZ6x9EZ4G2ZWOOlQZ')
      assert_equal(uri.album_name, 'Yes! プリキュア5 ボーカルベスト!! 【Yes! プリキュア5】')

      uri = SpotifyURI.parse('https://open.spotify.com/album/7xtiD9nNWrbbAtbbInNllD')
      assert_equal(uri.album_name, 'Yes! プリキュア5 ボーカルベスト!! 【Yes! プリキュア5】')
    end

    def test_track_name
      uri = SpotifyURI.parse('https://open.spotify.com')
      assert_nil(uri.track_name)

      uri = SpotifyURI.parse('https://open.spotify.com/track/7f47OJZ6x9EZ4G2ZWOOlQZ')
      assert_equal(uri.track_name, 'ガンバランスdeダンス ~夢みる奇跡たち~')

      uri = SpotifyURI.parse('https://open.spotify.com/album/7xtiD9nNWrbbAtbbInNllD')
      assert_nil(uri.track_name)
    end

    def test_artists
      uri = SpotifyURI.parse('https://open.spotify.com')
      assert_nil(uri.artists)

      uri = SpotifyURI.parse('https://open.spotify.com/track/7f47OJZ6x9EZ4G2ZWOOlQZ')
      assert_equal(uri.artists, ['宮本佳那子'])

      uri = SpotifyURI.parse('https://open.spotify.com/album/7xtiD9nNWrbbAtbbInNllD')
      assert_equal(uri.artists, ['ヴァリアス・アーティスト'])
    end

    def test_image_uri
      uri = SpotifyURI.parse('https://open.spotify.com')
      assert_nil(uri.image_uri)

      uri = SpotifyURI.parse('https://open.spotify.com/track/2j7bBkmzkl2Yz6oAsHozX0')
      assert_kind_of(Ginseng::URI, uri.image_uri)
    end
  end
end
