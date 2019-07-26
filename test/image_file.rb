module MulukhiyaTootProxy
  class ImageeFileTest < Test::Unit::TestCase
    def setup
      @file = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/icon.png'))
    end

    def test_image?
      assert(@file.image?)
    end

    def test_mime_type
      assert_equal(@file.mime_type, 'image/png')
    end

    def test_type
      assert_equal(@file.type, 'image/png')
    end

    def test_width
      assert_equal(@file.width, 128)
    end

    def test_height
      assert_equal(@file.height, 128)
    end

    def test_aspect
      assert_equal(@file.aspect, 1.0)
    end

    def test_long_side
      assert_equal(@file.long_side, 128)
    end

    def test_alpha?
      assert(@file.alpha?)
    end

    def test_resize
      converted = @file.resize(32)
      assert(converted.is_a?(ImageFile))
      assert_equal(converted.width, 32)
      assert_equal(converted.height, 32)
    end

    def test_convert_type
      converted = @file.convert_type(:jpeg)
      assert(converted.is_a?(ImageFile))
      assert_equal(converted.type, 'image/jpeg')
    end
  end
end
