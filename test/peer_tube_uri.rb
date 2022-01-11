module Mulukhiya
  class PeerTubeURITest < TestCase
    def setup
      @root = PeerTubeURI.parse('https://fedimovie.com/')
      @video = PeerTubeURI.parse('https://fedimovie.com/api/v1/videos/iKu2ASqiBm796yuzqdx9Zt')
    end

    def test_data
      assert_nil(@root.data)
      assert_kind_of(Hash, @video.data)
    end

    def test_title
      assert_nil(@root.title)
      assert_equal(@video.title, '[LIVE] DJMAXをただやるだけ。')
    end

    def test_album_name
      assert_nil(@root.album_name)
      assert_nil(@video.album_name)
    end

    def test_album?
      assert_false(@root.album?)
      assert_false(@video.album?)
    end

    def test_track_name
      assert_nil(@root.track_name)
      assert_equal(@video.track_name, '[LIVE] DJMAXをただやるだけ。')
    end

    def test_track?
      assert_false(@root.track?)
      assert(@video.track?)
    end

    def test_artists
      assert_nil(@root.artists)
      assert_equal(@video.artists, Set['鴉河雛@PeerTube'])
    end
  end
end
