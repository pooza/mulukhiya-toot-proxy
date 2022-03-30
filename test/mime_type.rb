module Mulukhiya
  class MIMETypeTest < TestCase
    def setup
      @mime = MIMEType.instance
    end

    def test_types
      assert_kind_of(Hash, @mime.types)
    end

    def test_type
      assert_equal('image/jpeg', @mime.type('.jpeg'))
      assert_equal('image/jpeg', @mime.type('.jpg'))
      assert_equal('image/png', @mime.type('.png'))
      assert_equal('image/webp', @mime.type('.webp'))
      assert_equal('video/mp4', @mime.type('.mp4'))
      assert_equal('video/x-matroska', @mime.type('.mkv'))
      assert_equal('audio/mpeg', @mime.type('.mp3'))
      assert_equal('text/markdown', @mime.type('.md'))
      assert_equal('audio/mpeg', @mime.type(File.join(Environment.dir, 'public/mulukhiya/media/hugttocatch.mp3')))
    end

    def test_extnames
      assert_kind_of(Hash, @mime.extnames)
    end

    def test_extname
      assert_equal('.jpg', @mime.extname('image/jpeg'))
      assert_equal('.png', @mime.extname('image/png'))
      assert_equal('.webp', @mime.extname('image/webp'))
      assert_equal('.mp4', @mime.extname('video/mp4'))
      assert_equal('.mkv', @mime.extname('video/x-matroska'))
      assert_equal('.mp3', @mime.extname('audio/mpeg'))
      assert_equal('.md', @mime.extname('text/markdown'))
    end
  end
end
