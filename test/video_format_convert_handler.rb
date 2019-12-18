module MulukhiyaTootProxy
  class VideoFormatConvertHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('video_format_convert')
      @handler.handle_pre_upload(file: {
        tmpfile: File.new(
          File.join(Environment.dir, 'sample/poyke.mp4'),
        ),
      })
    end

    def test_convertable?
      return if @handler.nil? || @handler.disable?
      assert_false(@handler.convertable?)
    end
  end
end
