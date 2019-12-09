module MulukhiyaTootProxy
  class ImageFormatConvertHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('image_format_convert')
      @handler.handle_pre_upload(file: {
        tmpfile: File.new(
          File.join(Environment.dir, 'public/mulukhiya/icon.png'),
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
