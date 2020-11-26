module Mulukhiya
  class ImageFileTest < TestCase
    def setup
      @png = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/ribbon08-009.png'))
      @mp3 = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/hugttocatch.mp3'))
      @mp4 = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/poyke.mp4'))
      @agif = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/11750_thumbnail.gif'))
      @awebp = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/animated-webp-supported.webp'))
      @apng = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/elephant_apng_zopfli.png'))
    end

    def test_image?
      assert(@png.image?)
      assert_false(@mp3.image?)
      assert_false(@mp4.image?)
      assert(@agif.image?)
      assert(@awebp.image?)
      assert(@apng.image?)
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
      assert(@agif.animated?)
      assert(@awebp.animated?) unless Environment.ci?
      assert(@apng.animated?)
    end

    def test_recommended_extname
      assert_equal(@png.recommended_extname, '.png')
    end

    def test_recommended_extname?
      assert(@png.recommended_extname?)
      assert(@agif.recommended_extname?)
      assert(@awebp.recommended_extname?)
      assert(@apng.recommended_extname?)
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

    def test_convert_animation_type
      assert_nil(@png.convert_animation_type)
      assert_nil(@agif.convert_animation_type)
      assert_equal(@awebp.convert_animation_type.type, 'image/gif') unless Environment.ci?
      assert_equal(@apng.convert_animation_type.type, 'image/gif')
    end
  end
end
