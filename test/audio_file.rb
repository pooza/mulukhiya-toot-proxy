module Mulukhiya
  class AudioFileTest < TestCase
    def setup
      @file = AudioFile.new(File.join(Environment.dir, 'public/mulukhiya/hugttocatch.mp3'))
    end

    def test_audio?
      assert(@file.audio?)
    end

    def test_mediatype
      assert_equal(@file.mediatype, 'audio')
    end

    def test_subtype
      assert_equal(@file.subtype, 'mpeg')
    end

    def test_type
      assert_equal(@file.type, 'audio/mpeg')
    end

    def test_duration
      assert_equal(@file.duration, 5.041625)
    end

    def test_convert_format
      converted = @file.convert_format(:mp3)
      assert_kind_of(AudioFile, converted)
      assert_equal(converted.type, 'audio/mpeg')
    end
  end
end
