module MulukhiyaTootProxy
  class AudioFormatHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('audio_format')
      @handler.handle_pre_upload(file: {
        tmpfile: File.new(
          File.join(Environment.dir, 'sample/hugttocatch.mp3'),
        ),
      })
    end

    def test_convertable?
      return if Environment.ci?
      assert_false(@handler.convertable?)
    end
  end
end
