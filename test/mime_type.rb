module Mulukhiya
  class MIMETypeTest < TestCase
    def setup
      @mime = MIMEType.instance
    end

    def test_types
      assert_kind_of(Hash, @mime.types)
    end

    def test_type
      assert_equal(@mime.type('.jpeg'), 'image/jpeg')
      assert_equal(@mime.type('.jpg'), 'image/jpeg')
      assert_equal(@mime.type('.png'), 'image/png')
      assert_equal(@mime.type('.mp4'), 'video/mp4')
      assert_equal(@mime.type('.mp3'), 'audio/mpeg')
    end

    def test_extnames
      assert_kind_of(Hash, @mime.extnames)
    end

    def test_extname
      assert_equal(@mime.extname('image/jpeg'), '.jpg')
      assert_equal(@mime.extname('image/png'), '.png')
      assert_equal(@mime.extname('video/mp4'), '.mp4')
      assert_equal(@mime.extname('audio/mpeg'), '.mp3')
    end
  end
end
