module Mulukhiya
  class YouTubeURITest < TestCase
    def setup
      @root = YouTubeURI.parse('https://www.youtube.com')
      @video = YouTubeURI.parse('https://www.youtube.com/watch?v=uFfsTeExwbQ')
      @music = YouTubeURI.parse('https://music.youtube.com/watch?v=mwJiuNq1eHY&list=RDAMVMmwJiuNq1eHY')
    end

    def test_title
      assert_nil(@root.title)
      assert_equal(@video.title, '【キラキラ☆プリキュアアラモード】後期エンディング 「シュビドゥビ☆スイーツタイム」 （歌：宮本佳那子）')
      assert_equal(@music.title, 'キミに100パーセント')
    end

    def test_music?
      assert_false(@root.music?)
      assert_false(@video.music?)
      assert(@music.music?)
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
      assert_equal(@video.track_name, '【キラキラ☆プリキュアアラモード】後期エンディング 「シュビドゥビ☆スイーツタイム」 （歌：宮本佳那子）')
      assert_equal(@music.track_name, 'キミに100パーセント')
    end

    def test_track?
      assert_false(@root.track?)
      assert(@video.track?)
      assert(@music.track?)
    end

    def test_artists
      assert_nil(@root.artists)
      assert_equal(@video.artists, ['プリキュア公式YouTubeチャンネル'])
      assert_equal(@music.artists, ['宮本佳那子'])
    end
  end
end
