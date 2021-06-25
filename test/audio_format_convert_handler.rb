module Mulukhiya
  class AudioFormatConvertHandlerTest < TestCase
    def setup
      @handler = Handler.create('audio_format_convert')
      @handler.handle_pre_upload(file: {
        tempfile: File.new(File.join(Environment.dir, 'public/mulukhiya/media/hugttocatch.mp3')),
      })
    end

    def test_convertable?
      assert_false(@handler.convertable?)
    end

    def test_convert
      assert_kind_of(AudioFile, @handler.convert)
    end
  end
end
