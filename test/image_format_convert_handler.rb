module MulukhiyaTootProxy
  class ImageFormatConvertHandlerTest < HandlerTest
    def setup
      @handler = Handler.create('image_format_convert')
      return if @handler.nil? || @handler.disable?
      @handler.handle_pre_upload(file: {
        tmpfile: File.new(
          File.join(Environment.dir, 'public/mulukhiya/icon.png'),
        ),
      })
    end

    def test_convertable?
      return if @handler.nil? || @handler.disable?
      assert_false(@handler.convertable?)
    end
  end
end
