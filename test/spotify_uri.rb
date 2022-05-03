module Mulukhiya
  class SpotifyURITest < TestCase
    def setup
      @google = SpotifyURI.parse('https://google.com')
      @root = SpotifyURI.parse('https://spotify.com')
      @track = SpotifyURI.parse('https://open.spotify.com/track/7f47OJZ6x9EZ4G2ZWOOlQZ')
      @album = SpotifyURI.parse('https://open.spotify.com/album/7xtiD9nNWrbbAtbbInNllD')
    end

    def test_spotify?
      assert_false(@google.spotify?)
      assert_predicate(@root, :spotify?)
      assert_predicate(@track, :spotify?)
      assert_predicate(@album, :spotify?)
    end

    def test_track_id
      assert_nil(@root.track_id)
      assert_equal('7f47OJZ6x9EZ4G2ZWOOlQZ', @track.track_id)
      assert_nil(@album.track_id)
    end

    def test_track
      assert_nil(@root.track)
      assert_kind_of(RSpotify::Track, @track.track)
      assert_nil(@album.track)
    end

    def test_track?
      assert_false(@root.track?)
      assert_predicate(@track, :track?)
      assert_false(@album.track?)
    end

    def test_album_id
      assert_nil(@root.album_id)
      assert_nil(@track.album_id)
      assert_equal('7xtiD9nNWrbbAtbbInNllD', @album.album_id)
    end

    def test_album
      assert_nil(@root.album)
      assert_kind_of(RSpotify::Album, @track.album)
      assert_kind_of(RSpotify::Album, @album.album)
    end

    def test_album?
      assert_false(@root.album?)
      assert_false(@track.album?)
      assert_predicate(@album, :album?)
    end

    def test_title
      assert_nil(@root.title)
      assert_equal('ガンバランスdeダンス ~夢みる奇跡たち~', @track.title)
      assert_equal('Yes! プリキュア5 ボーカルベスト!! 【Yes! プリキュア5】', @album.title)
    end

    def test_album_name
      assert_nil(@root.album_name)
      assert_equal('Yes! プリキュア5 ボーカルベスト!! 【Yes! プリキュア5】', @track.album_name)
      assert_equal('Yes! プリキュア5 ボーカルベスト!! 【Yes! プリキュア5】', @album.album_name)
    end

    def test_track_name
      assert_nil(@root.track_name)
      assert_equal('ガンバランスdeダンス ~夢みる奇跡たち~', @track.track_name)
      assert_nil(@album.track_name)
    end

    def test_artists
      assert_nil(@root.artists)
      assert_equal(@track.artists, Set['宮本佳那子'])
      assert_equal(@album.artists, Set['ヴァリアス・アーティスト'])
    end

    def test_image_uri
      assert_nil(@root.image_uri)
      assert_kind_of(Ginseng::URI, @track.image_uri)
      assert_predicate(@track.image_uri, :absolute?)
      assert_nil(@album.image_uri)
    end
  end
end
