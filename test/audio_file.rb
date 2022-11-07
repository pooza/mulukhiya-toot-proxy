module Mulukhiya
  class AudioFileTest < TestCase
    def setup
      @mp3 = AudioFile.new(File.join(Environment.dir, 'public/mulukhiya/media/hugttocatch.mp3'))
      @png = AudioFile.new(File.join(Environment.dir, 'public/mulukhiya/media/ribbon08-009.png'))
      @mp4 = AudioFile.new(File.join(Environment.dir, 'public/mulukhiya/media/poyke.mp4'))
    end

    def test_values
      assert_kind_of(Hash, @mp3.values)
    end

    def test_audio?
      assert_predicate(@mp3, :audio?)
      assert_false(@png.audio?)
      assert_false(@mp4.audio?)
    end

    def test_mediatype
      assert_equal('audio', @mp3.mediatype)
    end

    def test_subtype
      assert_equal('mpeg', @mp3.subtype)
    end

    def test_type
      assert_equal('audio/mpeg', @mp3.type)
    end

    def test_duration
      assert_in_delta(@mp3.duration, 5.041625)
    end

    def test_convert_type
      converted = @mp3.convert_type('audio/mpeg')

      assert_kind_of(AudioFile, converted)
      assert_equal('audio/mpeg', converted.type)
    end
  end
end
