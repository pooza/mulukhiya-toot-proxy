module Mulukhiya
  # Apple Music の MV の URL を短縮する (#4897)。pooza/makoto2 の曲紹介が貼る形。
  class ItunesMusicVideoURITest < TestCase
    def setup
      @music = ItunesMusicVideoURI.parse('https://music.apple.com')
      @long = ItunesMusicVideoURI.parse('https://music.apple.com/jp/music-video/%E3%81%AD%E3%81%93%E3%81%96%E3%81%8B%E3%81%AA%E3%83%80%E3%83%B3%E3%82%B7%E3%83%B3%E3%82%B0/1312882764?uo=4')
      @mv = ItunesMusicVideoURI.parse('https://music.apple.com/jp/music-video/1312882764')
    end

    def test_music_video_id
      assert_nil(@music.music_video_id)
      assert_equal(1_312_882_764, @long.music_video_id)
      assert_equal(1_312_882_764, @mv.music_video_id)
    end

    def test_id
      assert_nil(@music.id)
      assert_equal(1_312_882_764, @mv.id)
    end

    def test_shortenable?
      assert_false(@music.shortenable?)
      assert_predicate(@long, :shortenable?)
      assert_predicate(@mv, :shortenable?)
    end

    def test_shorten
      assert_equal('https://music.apple.com/jp/music-video/1312882764', @long.shorten.to_s)
      assert_equal('https://music.apple.com/jp/music-video/1312882764', @mv.shorten.to_s)
    end

    def test_create
      assert_kind_of(ItunesMusicVideoURI, ItunesURI.create(@long.to_s))
      assert_kind_of(ItunesSongURI, ItunesURI.create('https://music.apple.com/jp/song/1789469289'))
    end

    def test_not_song_or_album
      assert_false(@mv.song?)
      assert_false(@mv.album?)
      assert_false(@mv.track?)
    end

    def test_title
      assert_nil(@music.title)
      return unless @mv.track

      assert_equal('ねこざかなダンシング', @mv.title)
    end
  end
end
