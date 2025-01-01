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
  end
end
