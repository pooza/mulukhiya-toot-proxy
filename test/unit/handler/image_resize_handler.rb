module Mulukhiya
  class ImageResizeHandlerTest < TestCase
    def setup
      @handler = Handler.create(:image_resize)
      @handler.handle_pre_upload(file: {
        tempfile: File.new(
          File.join(Environment.dir, 'public/mulukhiya/media/icon.png'),
        ),
      })
    end

    def test_convertable?
      assert_false(@handler.convertable?)
    end

    def test_convert
      assert_kind_of(ImageFile, @handler.convert)
    end
  end
end
