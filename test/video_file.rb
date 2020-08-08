module Mulukhiya
  class VideoFileTest < TestCase
    def setup
      @mp4 = VideoFile.new(File.join(Environment.dir, 'public/mulukhiya/poyke.mp4'))
      @mkv = VideoFile.new(File.join(Environment.dir, 'public/mulukhiya/poyke.mkv'))
    end

    def test_video?
      assert(@mp4.video?)
      assert(@mkv.video?)
    end

    def test_mediatype
      assert_equal(@mp4.mediatype, 'video')
      assert_equal(@mkv.mediatype, 'video')
    end

    def test_subtype
      assert_equal(@mp4.subtype, 'mp4')
      assert_equal(@mkv.subtype, 'x-h264')
    end

    def test_type
      assert_equal(@mp4.type, 'video/mp4')
      assert_equal(@mkv.type, 'video/x-h264')
    end

    def test_width
      assert_equal(@mp4.width, 320)
      assert_equal(@mkv.width, 320)
    end

    def test_height
      assert_equal(@mp4.height, 180)
      assert_equal(@mkv.height, 180)
    end

    def test_aspect
      assert_equal(@mp4.aspect, 1.7777777777777777)
      assert_equal(@mkv.aspect, 1.7777777777777777)
    end

    def test_long_side
      assert_equal(@mp4.long_side, 320)
      assert_equal(@mkv.long_side, 320)
    end

    def test_duration
      assert_equal(@mp4.duration, 14.32)
    end

    def test_convert_format
      converted = @mp4.convert_format(:mp4)
      assert_kind_of(VideoFile, converted)
      assert_equal(converted.type, 'video/mp4')
    end
  end
end
