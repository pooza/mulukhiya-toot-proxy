module MulukhiyaTootProxy
  class ImageResizeHandlerTest < TestCase
    def setup
      @handler = Handler.create('image_resize')
      return unless handler?
      @handler.handle_pre_upload(file: {
        tmpfile: File.new(
          File.join(Environment.dir, 'public/mulukhiya/icon.png'),
        ),
      })
    end

    def test_convertable?
      return unless handler?
      assert_false(@handler.convertable?)
    end
  end
end
