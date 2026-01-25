module Mulukhiya
  class ItunesTrackURITest < TestCase
    def setup
      @google = ItunesTrackURI.parse('https://google.com')
      @apple = ItunesTrackURI.parse('https://apple.com')
      @itunes = ItunesTrackURI.parse('https://itunes.apple.com')
      @music = ItunesTrackURI.parse('https://music.apple.com')
      @long = ItunesTrackURI.parse('https://music.apple.com/jp/album/%E3%82%B7%E3%83%A5%E3%83%92-%E3%83%88-%E3%82%A5%E3%83%92-%E3%82%B9%E3%82%A4%E3%83%BC%E3%83%84%E3%82%BF%E3%82%A4%E3%83%A0/1299587212?i=1299587213&uo=4')
      @track = ItunesTrackURI.parse('https://music.apple.com/jp/album/1299587212?i=1299587213&uo=4')
      @album = ItunesTrackURI.parse('https://music.apple.com/jp/album/1299587212?uo=4')
    end

    def test_itunes?
      assert_false(@google.itunes?)
      assert_false(@apple.itunes?)
      assert_predicate(@itunes, :itunes?)
      assert_predicate(@music, :itunes?)
    end

    def test_album_id
      assert_nil(@music.album_id)
      assert_equal(1_299_587_212, @track.album_id)

      uri = @track.clone
      uri.album_id = '1299587999'

      assert_equal(1_299_587_999, uri.album_id)
    end

    def test_track_id
      assert_nil(@music.track_id)
      assert_equal(1_299_587_213, @track.track_id)

      uri = @track.clone
      uri.track_id = '1299587999'

      assert_equal(1_299_587_999, uri.track_id)
    end

    def test_shortenable?
      assert_false(@music.shortenable?)
      assert_predicate(@long, :shortenable?)
      assert_predicate(@track, :shortenable?)
      assert_predicate(@album, :shortenable?)
    end

    def test_shorten
      assert_equal('https://music.apple.com', @music.shorten.to_s)
      assert_equal('https://music.apple.com/jp/album/1299587212?i=1299587213&uo=4', @long.shorten.to_s)
      assert_equal('https://music.apple.com/jp/album/1299587212?i=1299587213&uo=4', @track.shorten.to_s)
      assert_equal('https://music.apple.com/jp/album/1299587212?uo=4', @album.shorten.to_s)
    end

    def test_title
      assert_nil(@music.title)
      assert_equal('シュビドゥビ☆スイーツタイム', @track.title)
      assert_equal('「キラキラ☆プリキュアアラモード」後期主題歌シングルED:シュビドゥビ☆スイーツタイム/挿入歌:勇気が君を待ってる - EP', @album.title)
    end

    def test_album?
      assert_false(@music.album?)
      assert_false(@track.album?)
      assert_predicate(@album, :album?)
    end

    def test_album_name
      assert_nil(@music.album_name)
      assert_equal('「キラキラ☆プリキュアアラモード」後期主題歌シングルED:シュビドゥビ☆スイーツタイム/挿入歌:勇気が君を待ってる - EP', @track.album_name)
      assert_equal('「キラキラ☆プリキュアアラモード」後期主題歌シングルED:シュビドゥビ☆スイーツタイム/挿入歌:勇気が君を待ってる - EP', @album.album_name)
    end

    def test_track?
      assert_false(@music.track?)
      assert_predicate(@track, :track?)
      assert_false(@album.track?)
    end

    def test_track_name
      assert_nil(@music.track_name)
      assert_equal('シュビドゥビ☆スイーツタイム', @track.track_name)
      assert_nil(@album.track_name)
    end

    def test_artists
      assert_nil(@music.artists)
      assert_equal(@track.artists, Set['宮本佳那子'])
      assert_equal(@album.artists, Set['歌:宮本佳那子/駒形友梨'])
    end

    def test_image_uri
      assert_nil(@music.image_uri)
      assert_kind_of(Ginseng::URI, @track.image_uri)
      assert_predicate(@track.image_uri, :absolute?)
      assert_kind_of(Ginseng::URI, @album.image_uri)
      assert_predicate(@album.image_uri, :absolute?)
    end
  end
end
