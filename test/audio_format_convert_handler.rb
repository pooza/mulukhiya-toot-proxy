module Mulukhiya
  class AudioFormatConvertHandlerTest < TestCase
    def setup
      @handler = Handler.create('audio_format_convert')
      return unless handler?
      @handler.handle_pre_upload(file: {
        tempfile: File.new(
          File.join(Environment.dir, 'public/mulukhiya/hugttocatch.mp3'),
        ),
      })
    end

    def test_convertable?
      return unless handler?
      assert_false(@handler.convertable?)
    end

    def test_convert
      return unless handler?
      assert_kind_of(AudioFile, @handler.convert)
    end
  end
end
