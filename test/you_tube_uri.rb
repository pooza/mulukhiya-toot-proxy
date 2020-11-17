module Mulukhiya
  class YouTubeURITest < TestCase
    def test_title
      uri = ItunesURI.parse('https://www.youtube.com')
      assert_nil(uri.title)

      uri = ItunesURI.parse('https://www.youtube.com/watch?v=uFfsTeExwbQ')
      assert_equal(uri.title, '【キラキラ☆プリキュアアラモード】後期エンディング 「シュビドゥビ☆スイーツタイム」 （歌：宮本佳那子）')

      uri = ItunesURI.parse('https://music.youtube.com/watch?v=mwJiuNq1eHY&list=RDAMVMmwJiuNq1eHY')
      assert_equal(uri.title, 'キミに100パーセント')
    end

    def test_album_name
      uri = ItunesURI.parse('https://www.youtube.com')
      assert_nil(uri.album_name)

      uri = ItunesURI.parse('https://www.youtube.com/watch?v=uFfsTeExwbQ')
      assert_nil(uri.album_name)

      uri = ItunesURI.parse('https://music.youtube.com/watch?v=mwJiuNq1eHY&list=RDAMVMmwJiuNq1eHY')
      assert_nil(uri.album_name)
    end

    def test_track_name
      uri = ItunesURI.parse('https://www.youtube.com')
      assert_nil(uri.track_name)

      uri = ItunesURI.parse('https://www.youtube.com/watch?v=uFfsTeExwbQ')
      assert_equal(uri.track_name, '【キラキラ☆プリキュアアラモード】後期エンディング 「シュビドゥビ☆スイーツタイム」 （歌：宮本佳那子）')

      uri = ItunesURI.parse('https://music.youtube.com/watch?v=mwJiuNq1eHY&list=RDAMVMmwJiuNq1eHY')
      assert_equal(uri.track_name, 'キミに100パーセント')
    end

    def test_artists
      uri = ItunesURI.parse('https://www.youtube.com')
      assert_nil(uri.artists)

      uri = ItunesURI.parse('https://www.youtube.com/watch?v=uFfsTeExwbQ')
      assert_equal(uri.artists, ['プリキュア公式YouTubeチャンネル'])

      uri = ItunesURI.parse('https://music.youtube.com/watch?v=mwJiuNq1eHY&list=RDAMVMmwJiuNq1eHY')
      assert_equal(uri.artists, ['宮本佳那子'])
    end
  end
end
