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

      assert_predicate(@handler, :convertable?)
    end

    def test_convertable_gif?
      @handler.handle_pre_upload(file: {
        tempfile: File.new(
          File.join(Environment.dir, 'public/mulukhiya/media/file_example_GIF_500kB.gif'),
        ),
      })

      assert_false(@handler.convertable?)
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
