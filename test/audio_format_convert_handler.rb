module MulukhiyaTootProxy
  class AudioFormatConvertHandlerTest < TestCase
    def setup
      @handler = Handler.create('audio_format_convert')
      return if invalid_handler?
      @handler.handle_pre_upload(file: {
        tmpfile: File.new(
          File.join(Environment.dir, 'sample/hugttocatch.mp3'),
        ),
      })
    end

    def test_convertable?
      return if invalid_handler?
      assert_false(@handler.convertable?)
    end
  end
end
