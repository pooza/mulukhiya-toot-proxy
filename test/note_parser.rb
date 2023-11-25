module Mulukhiya
  class NoteParserTest < TestCase
    def disable?
      return true unless Environment.note?
      return super
    end

    def setup
      @parser = NoteParser.new('さぁデリシャススマイル・フルパワーで')
      @mfm_parser = NoteParser.new('[YouTube](https://www.youtube.com) and [Google](https://google.com)')
    end

    def test_default_max_length
      assert_kind_of(Integer, @parser.default_max_length)
    end

    def test_to_mfm
      ic @mfm_parser
    end
  end
end
