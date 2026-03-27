module Mulukhiya
  class VideoFormatConvertHandlerTest < TestCase
    def setup
      @handler = Handler.create(:video_format_convert)
    end

    def test_convertable_h264_mp4
      load_file('h264_420.mp4')

      assert_false(@handler.convertable?)
    end

    def test_convertable_h264_mkv
      load_file('h264.mkv')

      assert_predicate(@handler, :convertable?)
    end

    def test_convertable_hevc_mp4
      load_file('hevc.mp4')

      assert_predicate(@handler, :convertable?)
    end

    def test_convertable_yuv444p
      load_file('h264.mp4')

      assert_predicate(@handler, :convertable?)
    end

    def test_convert_h264_mp4
      load_file('h264_420.mp4')
      converted = @handler.convert

      assert_kind_of(VideoFile, converted)
      assert_equal('h264', converted.video_codec)
      assert_equal('yuv420p', converted.pix_fmt)
    end

    def test_convert_h264_mkv
      load_file('h264.mkv')
      converted = @handler.convert

      assert_kind_of(VideoFile, converted)
      assert_equal('video/mp4', converted.type)
      assert_equal('h264', converted.video_codec)
    end

    def test_convert_hevc
      load_file('hevc.mp4')
      converted = @handler.convert

      assert_kind_of(VideoFile, converted)
      assert_equal('h264', converted.video_codec)
      assert_equal('yuv420p', converted.pix_fmt)
    end

    def test_convert_yuv444p_to_yuv420p
      load_file('h264.mp4')
      converted = @handler.convert

      assert_kind_of(VideoFile, converted)
      assert_equal('yuv420p', converted.pix_fmt)
    end

    def test_convert_noaudio
      load_file('noaudio.mp4')
      converted = @handler.convert

      assert_kind_of(VideoFile, converted)
    end

    private

    def load_file(name)
      path = File.join(Environment.dir, 'public/mulukhiya/media', name)
      @handler.handle_pre_upload(file: {tempfile: File.new(path)})
    end
  end
end
