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
      length = parser.default_max_length

      assert_kind_of(Integer, length)
      assert_predicate(length, :positive?)
    end
  end
end
