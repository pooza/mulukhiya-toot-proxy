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
      @gif = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/file_example_GIF_500kB.gif'))
      @awebp = ImageFile.new(File.join(Environment.dir, 'public/mulukhiya/media/animated-webp-supported.webp'))
    end

    def test_values
      assert_kind_of(Hash, @png_rgba.values)
    end

    def test_image?
      assert_predicate(@png_rgba, :image?)
      assert_false(@mp3.image?)
      assert_false(@mp4.image?)
      assert_predicate(@webp, :image?)
      assert_predicate(@agif, :image?)
      assert_predicate(@awebp, :image?)
    end

    def test_mediatype
      assert_equal('image', @png_rgba.mediatype)
      assert_equal('image', @webp.mediatype)
    end

    def test_subtype
      assert_equal('png', @png_rgba.subtype)
      assert_equal('webp', @webp.subtype)
    end

    def test_type
      assert_equal('image/png', @png_rgba.type)
      assert_equal('image/webp', @webp.type)
    end

    def test_width
      assert_equal(140, @png_rgba.width)
      assert_equal(320, @webp.width)
    end

    def test_height
      assert_equal(130, @png_rgba.height)
      assert_equal(241, @webp.height)
    end

    def test_aspect
      assert_in_delta(@png_rgba.aspect, 1.0769230769230769)
      assert_in_delta(@webp.aspect, 1.3278008298755186)
    end

    def test_long_side
      assert_equal(140, @png_rgba.long_side)
      assert_equal(320, @webp.long_side)
    end

    def test_gif?
      assert_predicate(@agif, :gif?)
      assert_predicate(@gif, :gif?)
      assert_false(@png_rgb.gif?)
      assert_false(@webp.gif?)
    end

    def test_alpha?
      assert_predicate(@png_rgba, :alpha?)
      assert_false(@png_rgb.alpha?)
      assert_false(@webp.alpha?)
    end

    def test_animated?
      assert_false(@png_rgba.animated?)
      assert_predicate(@agif, :animated?)
      assert_false(@webp.animated?)
      assert_predicate(@awebp, :animated?) if config['/handler/animation_image_format_convert/webp']
    end

    def test_recommended_name
      assert_equal('4.sm-1.webp', @webp.recommended_name)
      assert_equal('本当はwebp画像.webp', @invalid_webp.recommended_name)
    end

    def test_recommended_extname
      assert_equal('.png', @png_rgba.recommended_extname)
      assert_equal('.webp', @webp.recommended_extname)
      assert_equal('.webp', @awebp.recommended_extname)
    end

    def test_recommended_extname?
      assert_predicate(@agif, :recommended_extname?)
      assert_predicate(@png_rgba, :recommended_extname?)
      assert_predicate(@webp, :recommended_extname?)
      assert_predicate(@awebp, :recommended_extname?)
    end

    def test_resize
      converted = @png_rgba.resize(32)

      assert_kind_of(ImageFile, converted)
      assert_equal(32, converted.width)
      assert_equal(30, converted.height)
    end

    def test_convert_type
      converted = @png_rgba.convert_type('image/jpeg')

      assert_kind_of(ImageFile, converted)
      assert_equal('image/jpeg', converted.type)
    end

    def test_convert_animation_type
      assert_nil(@png_rgba.convert_animation_type)
      assert_kind_of(ImageFile, @agif.convert_animation_type)
      assert_equal('image/gif', @awebp.convert_animation_type.type) if config['/handler/animation_image_format_convert/webp']
    end
  end
end
