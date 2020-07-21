module Mulukhiya
  class ImageeFileTest < TestCase
    def setup
      @file = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/ribbon08-009.png'))
    end

    def test_image?
      assert(@file.image?)
    end

    def test_mediatype
      assert_equal(@file.mediatype, 'image')
    end

    def test_subtype
      assert_equal(@file.subtype, 'png')
    end

    def test_type
      assert_equal(@file.type, 'image/png')
    end

    def test_width
      assert_equal(@file.width, 140)
    end

    def test_height
      assert_equal(@file.height, 130)
    end

    def test_aspect
      assert_equal(@file.aspect, 1.0769230769230769)
    end

    def test_long_side
      assert_equal(@file.long_side, 140)
    end

    def test_alpha?
      assert(@file.alpha?)
    end

    def test_resize
      converted = @file.resize(32)
      assert_kind_of(ImageFile, converted)
      assert_equal(converted.width, 32)
      assert_equal(converted.height, 30)
    end

    def test_convert_format
      converted = @file.convert_format(:jpeg)
      assert_kind_of(ImageFile, converted)
      assert_equal(converted.type, 'image/jpeg')
    end
  end
end
