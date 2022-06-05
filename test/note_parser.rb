module Mulukhiya
  class NoteParserTest < TestCase
    def disable?
      return true unless Environment.note?
      return super
    end

    def setup
      @parser = NoteParser.new('さぁデリシャススマイル・フルパワーで')
    end

    def test_default_max_length
      assert_kind_of(Integer, @parser.default_max_length)
    end
  end
end
