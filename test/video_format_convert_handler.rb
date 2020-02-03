module Mulukhiya
  class VideoFormatConvertHandlerTest < TestCase
    def setup
      @handler = Handler.create('video_format_convert')
      @handler.handle_pre_upload(file: {
        tmpfile: File.new(
          File.join(Environment.dir, 'public/mulukhiya/poyke.mp4'),
        ),
      })
    end

    def test_convertable?
      return unless handler?
      assert_false(@handler.convertable?)
    end
  end
end
