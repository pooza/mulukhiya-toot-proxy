module Mulukhiya
  class VideoFormatConvertHandlerTest < TestCase
    def setup
      @handler = Handler.create(:video_format_convert)
      @handler.handle_pre_upload(file: {
        tempfile: File.new(File.join(Environment.dir, 'public/mulukhiya/media/poyke.mp4')),
      })
    end

    def test_convertable?
      assert_false(@handler.convertable?)
    end

    def test_convert
      assert_kind_of(VideoFile, @handler.convert)
    end
  end
end
