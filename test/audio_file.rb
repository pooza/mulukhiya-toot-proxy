module Mulukhiya
  class AudioFileTest < TestCase
    def setup
      @mp3 = AudioFile.new(File.join(Environment.dir, 'public/mulukhiya/hugttocatch.mp3'))
      @png = AudioFile.new(File.join(Environment.dir, 'public/mulukhiya/ribbon08-009.png'))
      @mp4 = AudioFile.new(File.join(Environment.dir, 'public/mulukhiya/poyke.mp4'))
    end

    def test_audio?
      assert(@mp3.audio?)
      assert_false(@png.audio?)
      assert_false(@mp4.audio?)
    end

    def test_mediatype
      assert_equal(@mp3.mediatype, 'audio')
    end

    def test_subtype
      assert_equal(@mp3.subtype, 'mpeg')
    end

    def test_type
      assert_equal(@mp3.type, 'audio/mpeg')
    end

    def test_duration
      assert_equal(@mp3.duration, 5.041625)
    end

    def test_convert_format
      converted = @mp3.convert_format(:mp3)
      assert_kind_of(AudioFile, converted)
      assert_equal(converted.type, 'audio/mpeg')
    end
  end
end
