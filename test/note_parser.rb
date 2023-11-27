module Mulukhiya
  class NoteParserTest < TestCase
    def disable?
      return true unless Environment.note?
      return super
    end

    def setup
    end

    def test_default_max_length
      parser = NoteParser.new('さぁデリシャススマイル・フルパワーで')

      assert_kind_of(Integer, parser.default_max_length)
    end

    def test_mfmize
      parser = NoteParser.new('[YouTube](https://www.youtube.com) and [Google](https://google.com) https://www.amazon.co.jp')

      assert_equal('[YouTube](https://www.youtube.com) and [Google](https://google.com) [www.amazon.co.jp](https://www.amazon.co.jp)', parser.mfmize)
    end
  end
end
