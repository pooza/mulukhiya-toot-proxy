module Mulukhiya
  class YouTubeVideoURITest < TestCase
    def disable?
      return true unless YouTubeService.config?
      return super
    end

    def setup
      @root = YouTubeVideoURI.parse('https://www.youtube.com')
      @video = YouTubeVideoURI.parse('https://www.youtube.com/watch?v=uFfsTeExwbQ')
      @music = YouTubeVideoURI.parse('https://music.youtube.com/watch?v=mwJiuNq1eHY&list=RDAMVMmwJiuNq1eHY')
    end

    def test_title
      assert_nil(@root.title)
      assert_equal('【キラキラ☆プリキュアアラモード】後期エンディング 「シュビドゥビ☆スイーツタイム」 （歌：宮本佳那子）', @video.title)
      assert_equal('キミに100パーセント', @music.title)
    end

    def test_music?
      assert_false(@root.music?)
      assert_false(@video.music?)
      assert_predicate(@music, :music?)
    end

    def test_album_name
      assert_nil(@root.album_name)
      assert_nil(@video.album_name)
      assert_nil(@music.album_name)
    end

    def test_album?
      assert_false(@root.album?)
      assert_false(@video.album?)
      assert_false(@music.album?)
    end

    def test_track_name
      assert_nil(@root.track_name)
      assert_equal('【キラキラ☆プリキュアアラモード】後期エンディング 「シュビドゥビ☆スイーツタイム」 （歌：宮本佳那子）', @video.track_name)
      assert_equal('キミに100パーセント', @music.track_name)
    end

    def test_track?
      assert_false(@root.track?)
      assert_predicate(@video, :track?)
      assert_predicate(@music, :track?)
    end

    def test_artists
      assert_nil(@root.artists)
      assert_equal(@video.artists, Set['プリキュア公式YouTubeチャンネル'])
      assert_equal(@music.artists, Set['宮本佳那子'])
    end
  end
end
