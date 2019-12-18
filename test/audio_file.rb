module MulukhiyaTootProxy
  class AudioFileTest < TestCase
    def setup
      @file = AudioFile.new(File.join(Environment.dir, 'sample/hugttocatch.mp3'))
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

    def test_convert_type
      converted = @file.convert_type(:mp3)
      assert(converted.is_a?(AudioFile))
      assert_equal(converted.type, 'audio/mpeg')
    end
  end
end
