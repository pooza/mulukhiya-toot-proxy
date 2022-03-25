module Mulukhiya
  class PeerTubeURITest < TestCase
    def setup
      @root = PeerTubeURI.parse('https://fedimovie.com/')
      @video = PeerTubeURI.parse('https://fedimovie.com/w/taaJ1Sh8b5JvHUZeFD1Jzk')
      @videol = PeerTubeURI.parse('https://fedimovie.com/videos/watch/taaJ1Sh8b5JvHUZeFD1Jzk')
    end

    def test_data
      assert_nil(@root.data)
      assert_kind_of(Hash, @video.data)
      assert_kind_of(Hash, @videol.data)
    end

    def test_title
      assert_nil(@root.title)
      assert_equal('GPD Pocket 3 開封', @video.title)
      assert_equal('GPD Pocket 3 開封', @videol.title)
    end

    def test_album_name
      assert_nil(@root.album_name)
      assert_nil(@video.album_name)
      assert_nil(@videol.album_name)
    end

    def test_album?
      assert_false(@root.album?)
      assert_false(@video.album?)
      assert_false(@videol.album?)
    end

    def test_track_name
      assert_nil(@root.track_name)
      assert_equal('GPD Pocket 3 開封', @video.track_name)
      assert_equal('GPD Pocket 3 開封', @videol.track_name)
    end

    def test_track?
      assert_false(@root.track?)
      assert_predicate(@video, :track?)
      assert_predicate(@videol, :track?)
    end

    def test_artists
      assert_nil(@root.artists)
      assert_equal(@video.artists, Set['ぷーざ'])
      assert_equal(@videol.artists, Set['ぷーざ'])
    end
  end
end
