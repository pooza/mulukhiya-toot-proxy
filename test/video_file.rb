module Mulukhiya
  class VideoFileTest < TestCase
    def setup
      @file = VideoFile.new(File.join(Environment.dir, 'public/mulukhiya/poyke.mp4'))
    end

    def test_video?
      assert(@file.video?)
    end

    def test_mediatype
      assert_equal(@file.mediatype, 'video')
    end

    def test_subtype
      assert_equal(@file.subtype, 'mp4')
    end

    def test_type
      assert_equal(@file.type, 'video/mp4')
    end

    def test_width
      assert_equal(@file.width, 320)
    end

    def test_height
      assert_equal(@file.height, 180)
    end

    def test_aspect
      assert_equal(@file.aspect, 1.7777777777777777)
    end

    def test_long_side
      assert_equal(@file.long_side, 320)
    end

    def test_duration
      assert_equal(@file.duration, 14.32)
    end

    def test_convert_format
      converted = @file.convert_format(:mp4)
      assert_kind_of(VideoFile, converted)
      assert_equal(converted.type, 'video/mp4')
    end
  end
end
