module Mulukhiya
  class ImageFormatConvertHandlerTest < TestCase
    def setup
      @handler = Handler.create('image_format_convert')
      return unless handler?
      @handler.handle_pre_upload(file: {
        tempfile: File.new(
          File.join(Environment.dir, 'public/mulukhiya/media/icon.png'),
        ),
      })
    end

    def test_convertable?
      return unless handler?
      config['/handler/image_format_convert/alpha'] = true
      assert_false(@handler.convertable?)
      config['/handler/image_format_convert/alpha'] = false
      assert(@handler.convertable?)
    end

    def test_detect_alpha?
      return unless handler?
      assert_boolean(@handler.detect_alpha?)
    end

    def test_convert
      return unless handler?
      assert_kind_of(ImageFile, @handler.convert)
    end
  end
end
