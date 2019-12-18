module MulukhiyaTootProxy
  class ImageFormatConvertHandlerTest < TestCase
    def setup
      @handler = Handler.create('image_format_convert')
      return if invalid_handler?
      @handler.handle_pre_upload(file: {
        tmpfile: File.new(
          File.join(Environment.dir, 'public/mulukhiya/icon.png'),
        ),
      })
    end

    def test_convertable?
      return if invalid_handler?
      assert_false(@handler.convertable?)
    end
  end
end
