module Mulukhiya
  class ItunesURITest < TestCase
    def setup
      @google = ItunesURI.parse('https://google.com')
      @apple = ItunesURI.parse('https://apple.com')
      @itunes = ItunesURI.parse('https://itunes.apple.com')
      @music = ItunesURI.parse('https://music.apple.com')
      @long = ItunesURI.parse('https://music.apple.com/jp/album/%E3%82%B7%E3%83%A5%E3%83%92-%E3%83%88-%E3%82%A5%E3%83%92-%E3%82%B9%E3%82%A4%E3%83%BC%E3%83%84%E3%82%BF%E3%82%A4%E3%83%A0/1299587212?i=1299587213&uo=4')
      @track = ItunesURI.parse('https://music.apple.com/jp/album/1299587212?i=1299587213&uo=4')
      @album = ItunesURI.parse('https://music.apple.com/jp/album/1299587212?uo=4')
    end

    def test_itunes?
      assert_false(@google.itunes?)
      assert_false(@apple.itunes?)
      assert(@itunes.itunes?)
      assert(@music.itunes?)
    end

    def test_album_id
      assert_nil(@music.album_id)
      assert_equal(@track.album_id, 1_299_587_212)

      uri = @track.clone
      uri.album_id = '1299587999'
      assert_equal(uri.album_id, 1_299_587_999)
    end

    def test_track_id
      assert_nil(@music.track_id)
      assert_equal(@track.track_id, 1_299_587_213)

      uri = @track.clone
      uri.track_id = '1299587999'
      assert_equal(uri.track_id, 1_299_587_999)
    end

    def test_shortenable?
      assert_false(@music.shortenable?)
      assert(@long.shortenable?)
      assert(@track.shortenable?)
      assert(@album.shortenable?)
    end

    def test_shorten
      assert_equal(@music.shorten.to_s, 'https://music.apple.com')
      assert_equal(@long.shorten.to_s, 'https://music.apple.com/jp/album/1299587212?i=1299587213&uo=4')
      assert_equal(@track.shorten.to_s, 'https://music.apple.com/jp/album/1299587212?i=1299587213&uo=4')
      assert_equal(@album.shorten.to_s, 'https://music.apple.com/jp/album/1299587212?uo=4')
    end

    def test_title
      assert_nil(@music.title)
      assert_equal(@track.title, 'シュビドゥビ☆スイーツタイム')
      assert_equal(@album.title, '「キラキラ☆プリキュアアラモード」後期主題歌シングルED:シュビドゥビ☆スイーツタイム/挿入歌:勇気が君を待ってる - EP')
    end

    def test_album?
      assert_false(@music.album?)
      assert_false(@track.album?)
      assert(@album.album?)
    end

    def test_album_name
      assert_nil(@music.album_name)
      assert_equal(@track.album_name, '「キラキラ☆プリキュアアラモード」後期主題歌シングルED:シュビドゥビ☆スイーツタイム/挿入歌:勇気が君を待ってる - EP')
      assert_equal(@album.album_name, '「キラキラ☆プリキュアアラモード」後期主題歌シングルED:シュビドゥビ☆スイーツタイム/挿入歌:勇気が君を待ってる - EP')
    end

    def test_track?
      assert_false(@music.track?)
      assert(@track.track?)
      assert_false(@album.track?)
    end

    def test_track_name
      assert_nil(@music.track_name)
      assert_equal(@track.track_name, 'シュビドゥビ☆スイーツタイム')
      assert_nil(@album.track_name)
    end

    def test_artists
      assert_nil(@music.artists)
      assert_equal(@track.artists, ['宮本佳那子'])
      assert_equal(@album.artists, ['宮本佳那子', '駒形友梨'])
    end

    def test_image_uri
      assert_nil(@music.image_uri)
      assert_kind_of(Ginseng::URI, @track.image_uri)
      assert_kind_of(Ginseng::URI, @album.image_uri)
    end
  end
end
