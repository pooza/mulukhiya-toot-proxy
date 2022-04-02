module Mulukhiya
  class AnimationImageFormatConvertHandlerTest < TestCase
    def setup
      @handler = Handler.create(:animation_image_format_convert)
      @handler.handle_pre_upload(file: {
        tempfile: File.new(
          File.join(Environment.dir, 'public/mulukhiya/media/animated-webp-supported.webp'),
        ),
      })
    end

    def test_convertable?
      assert_boolean(@handler.convertable?)
    end

    def test_convert
      assert_kind_of([ImageFile, NilClass], @handler.convert)
    end
  end
end
