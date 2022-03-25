module Mulukhiya
  class VideoFileTest < TestCase
    def setup
      @mp4 = VideoFile.new(File.join(Environment.dir, 'public/mulukhiya/media/poyke.mp4'))
      @mkv = VideoFile.new(File.join(Environment.dir, 'public/mulukhiya/media/poyke.mkv'))
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
      assert_equal(320, @mp4.width)
      assert_equal(320, @mkv.width)
    end

    def test_height
      assert_equal(180, @mp4.height)
      assert_equal(180, @mkv.height)
    end

    def test_aspect
      assert_in_delta(@mp4.aspect, 1.7777777777777777)
      assert_in_delta(@mkv.aspect, 1.7777777777777777)
    end

    def test_long_side
      assert_equal(320, @mp4.long_side)
      assert_equal(320, @mkv.long_side)
    end

    def test_duration
      assert_in_delta(@mp4.duration, 14.32)
    end

    def test_convert_type
      converted = @mp4.convert_type('video/mp4')
      assert_kind_of(VideoFile, converted)
      assert_equal('video/mp4', converted.type)
    end
  end
end
