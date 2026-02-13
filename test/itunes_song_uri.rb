module Mulukhiya
  class ItunesSongURITest < TestCase
    def setup
      @music = ItunesSongURI.parse('https://music.apple.com')
      @long = ItunesSongURI.parse('https://music.apple.com/jp/song/%E7%AC%91%E9%A1%94%E3%81%AE%E3%83%A6%E3%83%8B%E3%82%BE%E3%83%B3/1789469289')
      @song = ItunesSongURI.parse('https://music.apple.com/jp/song/1789469289')
    end

    def test_song_id
      assert_nil(@music.song_id)
      assert_equal(1_789_469_289, @song.song_id)

      uri = @song.clone
      uri.song_id = '1789469999'

      assert_equal(1_789_469_999, uri.song_id)
    end

    def test_id
      assert_nil(@music.id)
      assert_equal(1_789_469_289, @song.id)
    end

    def test_shortenable?
      assert_false(@music.shortenable?)
      assert_predicate(@long, :shortenable?)
      assert_predicate(@song, :shortenable?)
    end

    def test_shorten
      assert_equal('https://music.apple.com/jp/song/1789469289', @long.shorten.to_s)
      assert_equal('https://music.apple.com/jp/song/1789469289', @song.shorten.to_s)
    end

    def test_song?
      assert_false(@music.song?)
      assert_predicate(@song, :song?)
    end

    def test_track?
      assert_false(@music.track?)
      assert_false(@song.track?)
    end

    def test_album?
      assert_false(@music.album?)
      assert_false(@song.album?)
    end

    def test_track_name
      assert_nil(@music.track_name)
      assert_equal('笑顔のユニゾン♪', @song.track_name)
    end

    def test_album_name
      assert_nil(@music.album_name)
      assert_equal('『キミとアイドルプリキュア♪』デビューシングル【通常盤】 - EP', @song.album_name)
    end

    def test_title
      assert_nil(@music.title)
      assert_equal('笑顔のユニゾン♪', @song.title)
    end

    def test_artists
      assert_nil(@music.artists)
      assert_equal(Set['キュアアイドル(CV:松岡美里)、キミとアイドルプリキュア♪'], @song.artists)
    end

    def test_image_uri
      assert_nil(@music.image_uri)
      return unless @song.image_uri

      assert_kind_of(Ginseng::URI, @song.image_uri)
      assert_predicate(@song.image_uri, :absolute?)
    end
  end
end
