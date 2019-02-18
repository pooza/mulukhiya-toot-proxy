module MulukhiyaTootProxy
  class ItunesURITest < Test::Unit::TestCase
    def test_itunes?
      uri = ItunesURI.parse('https://google.com')
      assert_false(uri.itunes?)

      uri = ItunesURI.parse('https://apple.com')
      assert_false(uri.itunes?)

      uri = ItunesURI.parse('https://itunes.apple.com')
      assert(uri.itunes?)
    end

    def test_album_id
      uri = ItunesURI.parse('https://itunes.apple.com')
      assert_nil(uri.album_id)

      uri = ItunesURI.parse('https://itunes.apple.com/jp/album/%E3%82%B7%E3%83%A5%E3%83%92-%E3%83%88-%E3%82%A5%E3%83%92-%E3%82%B9%E3%82%A4%E3%83%BC%E3%83%84%E3%82%BF%E3%82%A4%E3%83%A0/1299587212?i=1299587213&uo=4')
      assert_equal(uri.album_id, '1299587212')
    end

    def test_track_id
      uri = ItunesURI.parse('https://itunes.apple.com')
      assert_nil(uri.track_id)

      uri = ItunesURI.parse('https://itunes.apple.com/jp/album/%E3%82%B7%E3%83%A5%E3%83%92-%E3%83%88-%E3%82%A5%E3%83%92-%E3%82%B9%E3%82%A4%E3%83%BC%E3%83%84%E3%82%BF%E3%82%A4%E3%83%A0/1299587212?i=1299587213&uo=4')
      assert_equal(uri.track_id, '1299587213')
    end

    def test_image_uri
      uri = ItunesURI.parse('https://itunes.apple.com')
      assert_nil(uri.image_uri)

      uri = ItunesURI.parse('https://itunes.apple.com/jp/album/%E3%82%B7%E3%83%A5%E3%83%92-%E3%83%88-%E3%82%A5%E3%83%92-%E3%82%B9%E3%82%A4%E3%83%BC%E3%83%84%E3%82%BF%E3%82%A4%E3%83%A0/1299587212?i=1299587213&uo=4')
      assert(uri.image_uri.is_a?(Addressable::URI))
    end
  end
end
