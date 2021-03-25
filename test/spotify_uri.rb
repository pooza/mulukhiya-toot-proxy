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
      assert(@root.spotify?)
      assert(@track.spotify?)
      assert(@album.spotify?)
    end

    def test_track_id
      assert_nil(@root.track_id)
      assert_equal(@track.track_id, '7f47OJZ6x9EZ4G2ZWOOlQZ')
      assert_nil(@album.track_id)
    end

    def test_track
      assert_nil(@root.track)
      assert_kind_of(RSpotify::Track, @track.track)
      assert_nil(@album.track)
    end

    def test_track?
      assert_false(@root.track?)
      assert(@track.track?)
      assert_false(@album.track?)
    end

    def test_album_id
      assert_nil(@root.album_id)
      assert_nil(@track.album_id)
      assert_equal(@album.album_id, '7xtiD9nNWrbbAtbbInNllD')
    end

    def test_album
      assert_nil(@root.album)
      assert_kind_of(RSpotify::Album, @track.album)
      assert_kind_of(RSpotify::Album, @album.album)
    end

    def test_album?
      assert_false(@root.album?)
      assert_false(@track.album?)
      assert(@album.album?)
    end

    def test_title
      assert_nil(@root.title)
      assert_equal(@track.title, 'ガンバランスdeダンス ~夢みる奇跡たち~')
      assert_equal(@album.title, 'Yes! プリキュア5 ボーカルベスト!! 【Yes! プリキュア5】')
    end

    def test_album_name
      assert_nil(@root.album_name)
      assert_equal(@track.album_name, 'Yes! プリキュア5 ボーカルベスト!! 【Yes! プリキュア5】')
      assert_equal(@album.album_name, 'Yes! プリキュア5 ボーカルベスト!! 【Yes! プリキュア5】')
    end

    def test_track_name
      assert_nil(@root.track_name)
      assert_equal(@track.track_name, 'ガンバランスdeダンス ~夢みる奇跡たち~')
      assert_nil(@album.track_name)
    end

    def test_artists
      assert_nil(@root.artists)
      assert_equal(@track.artists, ['宮本佳那子'])
      assert_equal(@album.artists, ['ヴァリアス・アーティスト'])
    end

    def test_image_uri
      assert_nil(@root.image_uri)
      assert_kind_of(Ginseng::URI, @track.image_uri)
      assert_nil(@album.image_uri)
    end
  end
end
