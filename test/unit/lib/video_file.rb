module Mulukhiya
  class VideoFileTest < TestCase
    def setup
      @mp4 = VideoFile.new(File.join(Environment.dir, 'public/mulukhiya/media/h264.mp4'))
      @mp4_yuv420 = VideoFile.new(File.join(Environment.dir, 'public/mulukhiya/media/h264_420.mp4'))
      @hevc = VideoFile.new(File.join(Environment.dir, 'public/mulukhiya/media/hevc.mp4'))
      @mkv = VideoFile.new(File.join(Environment.dir, 'public/mulukhiya/media/h264.mkv'))
      @mov = VideoFile.new(File.join(Environment.dir, 'public/mulukhiya/media/h264.mov'))
      @hevc_mov = VideoFile.new(File.join(Environment.dir, 'public/mulukhiya/media/hevc.mov'))
      @noaudio = VideoFile.new(File.join(Environment.dir, 'public/mulukhiya/media/noaudio.mp4'))
      @m4v = VideoFile.new(File.join(Environment.dir, 'public/mulukhiya/media/h264.m4v'))
      @jpeg = VideoFile.new(File.join(Environment.dir, 'public/mulukhiya/media/logo.jpg'))
      @mp3 = VideoFile.new(File.join(Environment.dir, 'public/mulukhiya/media/hugttocatch.mp3'))
    end

    def test_values
      assert_kind_of(Hash, @mp4.values)
      assert_kind_of(Hash, @mkv.values)
    end

    def test_video?
      assert_predicate(@mp4, :video?)
      assert_predicate(@mkv, :video?)
      assert_false(@jpeg.video?)
      assert_false(@mp3.video?)
    end

    def test_mediatype
      assert_equal('video', @mp4.mediatype)
      assert_equal('video', @mkv.mediatype)
    end

    def test_subtype
      assert_equal('mp4', @mp4.subtype)
      assert_equal('x-matroska', @mkv.subtype)
    end

    def test_type
      assert_equal('video/mp4', @mp4.type)
      assert_equal('video/x-matroska', @mkv.type)
    end

    def test_width
      assert_equal(160, @mp4.width)
      assert_equal(160, @mkv.width)
      assert_equal(160, @mov.width)
    end

    def test_height
      assert_equal(120, @mp4.height)
      assert_equal(120, @mkv.height)
      assert_equal(120, @mov.height)
    end

    def test_aspect
      assert_in_delta(@mp4.aspect, 1.3333333333333333)
      assert_in_delta(@mkv.aspect, 1.3333333333333333)
    end

    def test_long_side
      assert_equal(160, @mp4.long_side)
      assert_equal(160, @mkv.long_side)
    end

    def test_duration
      assert_in_delta(@mp4.duration, 2.0)
    end

    def test_video_codec
      assert_equal('h264', @mp4.video_codec)
      assert_equal('hevc', @hevc.video_codec)
    end

    def test_convert_type
      converted = @mp4.convert_type('video/mp4')

      assert_kind_of(VideoFile, converted)
      assert_equal('video/mp4', converted.type)
    end

    def test_transcode_hevc
      converted = @hevc.transcode('video/mp4')

      assert_kind_of(VideoFile, converted)
      assert_equal('video/mp4', converted.type)
      assert_equal('h264', converted.video_codec)
    end

    def test_mov
      assert_predicate(@mov, :video?)
      assert_equal('video/quicktime', @mov.type)
      assert_equal('h264', @mov.video_codec)
    end

    def test_hevc_mov
      assert_predicate(@hevc_mov, :video?)
      assert_equal('video/quicktime', @hevc_mov.type)
      assert_equal('hevc', @hevc_mov.video_codec)
    end

    def test_noaudio
      assert_predicate(@noaudio, :video?)
      assert_equal('h264', @noaudio.video_codec)
    end

    def test_pix_fmt
      assert_equal('yuv444p', @mp4.pix_fmt)
      assert_equal('yuv420p', @mp4_yuv420.pix_fmt)
    end

    def test_m4v
      assert_predicate(@m4v, :video?)
      assert_equal('video/mp4', @m4v.type)
      assert_equal('h264', @m4v.video_codec)
    end

    def test_transcode_yuv444p
      converted = @mp4.transcode('video/mp4')

      assert_equal('yuv420p', converted.pix_fmt)
    end
  end
end
