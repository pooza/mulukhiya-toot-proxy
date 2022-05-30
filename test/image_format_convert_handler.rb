module Mulukhiya
  class ImageFormatConvertHandlerTest < TestCase
    def setup
      @handler = Handler.create(:image_format_convert)
    end

    def test_convertable?
      @handler.handle_pre_upload(file: {
        tempfile: File.new(
          File.join(Environment.dir, 'public/mulukhiya/media/icon.png'),
        ),
      })
      config['/handler/image_format_convert/alpha'] = true
      assert_false(@handler.convertable?)
      config['/handler/image_format_convert/alpha'] = false
      assert_predicate(@handler, :convertable?)

      @handler.handle_pre_upload(file: {
        tempfile: File.new(
          File.join(Environment.dir, 'public/mulukhiya/media/file_example_GIF_500kB.gif'),
        ),
      })
      config['/handler/image_format_convert/gif'] = true
      assert_false(@handler.convertable?)
      config['/handler/image_format_convert/gif'] = false
      assert_predicate(@handler, :convertable?)
    end

    def test_detect_alpha?
      assert_boolean(@handler.detect_alpha?)
    end

    def test_detect_gif?
      assert_boolean(@handler.detect_gif?)
    end

    def test_convert
      @handler.handle_pre_upload(file: {
        tempfile: File.new(
          File.join(Environment.dir, 'public/mulukhiya/media/icon.png'),
        ),
      })
      assert_kind_of(ImageFile, @handler.convert)
    end
  end
end
