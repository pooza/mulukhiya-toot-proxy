module Mulukhiya
  class ImageeFileTest < TestCase
    def setup
      @png = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/ribbon08-009.png'))
      @animated = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/animated-webp-supported.webp'))
    end

    def test_image?
      assert(@png.image?)
    end

    def test_mediatype
      assert_equal(@png.mediatype, 'image')
    end

    def test_subtype
      assert_equal(@png.subtype, 'png')
    end

    def test_type
      assert_equal(@png.type, 'image/png')
    end

    def test_width
      assert_equal(@png.width, 140)
    end

    def test_height
      assert_equal(@png.height, 130)
    end

    def test_aspect
      assert_equal(@png.aspect, 1.0769230769230769)
    end

    def test_long_side
      assert_equal(@png.long_side, 140)
    end

    def test_alpha?
      assert(@png.alpha?)
    end

    def test_animated?
      assert_false(@png.animated?)
      assert(@animated.animated?)
    end

    def test_valid_extname
      assert_equal(@png.valid_extname, '.png')
      assert_nil(@animated.valid_extname)
    end

    def test_valid_extname?
      assert(@png.valid_extname?)
      assert(@animated.valid_extname?)
    end

    def test_resize
      converted = @png.resize(32)
      assert_kind_of(ImageFile, converted)
      assert_equal(converted.width, 32)
      assert_equal(converted.height, 30)
    end

    def test_convert_format
      converted = @png.convert_format(:jpeg)
      assert_kind_of(ImageFile, converted)
      assert_equal(converted.type, 'image/jpeg')
    end
  end
end
