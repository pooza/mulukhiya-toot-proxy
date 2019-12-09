module MulukhiyaTootProxy
  class AudioFormatConvertHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('audio_format_convert')
      @handler.handle_pre_upload(file: {
        tmpfile: File.new(
          File.join(Environment.dir, 'sample/hugttocatch.mp3'),
        ),
      })
    end

    def test_convertable?
      return unless Postgres.config?
      return if @handler.disable?

      assert_false(@handler.convertable?)
    end
  end
end
