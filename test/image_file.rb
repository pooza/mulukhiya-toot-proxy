module Mulukhiya
  class ImageFileTest < TestCase
    def setup
      @png = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/ribbon08-009.png'))
      @animated = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/animated-webp-supported.webp'))
      @mp3 = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/hugttocatch.mp3'))
      @mp4 = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/poyke.mp4'))
    end

    def test_image?
      assert(@png.image?)
      assert(@animated.image?)
      assert_false(@mp3.image?)
      assert_false(@mp4.image?)
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
      assert(@animated.animated?) unless Environment.ci?
    end

    def test_recommended_extname
      assert_equal(@png.recommended_extname, '.png')
      assert_nil(@animated.recommended_extname)
    end

    def test_recommended_extname?
      assert(@png.recommended_extname?)
      assert(@animated.recommended_extname?)
    end

    def test_resize
      converted = @png.resize(32)
      assert_kind_of(ImageFile, converted)
      assert_equal(converted.width, 32)
      assert_equal(converted.height, 30)
    end

    def test_convert_type
      converted = @png.convert_type('image/jpeg')
      assert_kind_of(ImageFile, converted)
      assert_equal(converted.type, 'image/jpeg')
    end
  end
end
