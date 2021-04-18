module Mulukhiya
  class ImageFileTest < TestCase
    def setup
      @png_rgba = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/ribbon08-009.png'))
      @png_rgb = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/logo.png'))
      @mp3 = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/hugttocatch.mp3'))
      @mp4 = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/poyke.mp4'))
      @webp = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/4.sm-1.webp'))
      @invalid_webp = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/本当はwebp画像.png'))
      @agif = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/11750_thumbnail.gif'))
      @awebp = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/animated-webp-supported.webp'))
      @apng = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/elephant_apng_zopfli.png'))
    end

    def test_values
      assert_kind_of(Hash, @png_rgba.values)
    end

    def test_image?
      assert(@png_rgba.image?)
      assert_false(@mp3.image?)
      assert_false(@mp4.image?)
      assert(@webp.image?)
      assert(@agif.image?)
      assert(@awebp.image?)
      assert(@apng.image?)
    end

    def test_mediatype
      assert_equal(@png_rgba.mediatype, 'image')
      assert_equal(@webp.mediatype, 'image')
    end

    def test_subtype
      assert_equal(@png_rgba.subtype, 'png')
      assert_equal(@webp.subtype, 'webp')
    end

    def test_type
      assert_equal(@png_rgba.type, 'image/png')
      assert_equal(@webp.type, 'image/webp')
    end

    def test_width
      assert_equal(@png_rgba.width, 140)
      assert_equal(@webp.width, 320)
    end

    def test_height
      assert_equal(@png_rgba.height, 130)
      assert_equal(@webp.height, 241)
    end

    def test_aspect
      assert_equal(@png_rgba.aspect, 1.0769230769230769)
      assert_equal(@webp.aspect, 1.3278008298755186)
    end

    def test_long_side
      assert_equal(@png_rgba.long_side, 140)
      assert_equal(@webp.long_side, 320)
    end

    def test_alpha?
      assert(@png_rgba.alpha?)
      assert_false(@png_rgb.alpha?)
      assert_false(@webp.alpha?)
    end

    def test_animated?
      assert_false(@png_rgba.animated?)
      assert(@agif.animated?)
      assert_false(@webp.animated?)
      assert(@awebp.animated?) unless Environment.ci?
      assert(@apng.animated?)
    end

    def test_recommended_name
      assert_equal(@webp.recommended_name, '4.sm-1.webp')
      assert_equal(@invalid_webp.recommended_name, '本当はwebp画像.webp')
    end

    def test_recommended_extname
      assert_equal(@png_rgba.recommended_extname, '.png')
      assert_equal(@apng.recommended_extname, '.png')
      assert_equal(@webp.recommended_extname, '.webp')
      assert_equal(@awebp.recommended_extname, '.webp')
    end

    def test_recommended_extname?
      assert(@agif.recommended_extname?)
      assert(@png_rgba.recommended_extname?)
      assert(@apng.recommended_extname?)
      assert(@webp.recommended_extname?)
      assert(@awebp.recommended_extname?)
    end

    def test_resize
      converted = @png_rgba.resize(32)
      assert_kind_of(ImageFile, converted)
      assert_equal(converted.width, 32)
      assert_equal(converted.height, 30)
    end

    def test_convert_type
      converted = @png_rgba.convert_type('image/jpeg')
      assert_kind_of(ImageFile, converted)
      assert_equal(converted.type, 'image/jpeg')
    end

    def test_convert_animation_type
      assert_nil(@png_rgba.convert_animation_type)
      assert_nil(@agif.convert_animation_type)
      # assert_equal(@awebp.convert_animation_type.type, 'image/gif')
      assert_equal(@apng.convert_animation_type.type, 'image/gif')
    end
  end
end
