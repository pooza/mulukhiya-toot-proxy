module MulukhiyaTootProxy
  class NoteParserTest < TestCase
    def setup
      @parser = NoteParser.new
    end

    def test_too_long?
      @parser.body = 'ローリン♪ローリン♪ココロにズッキュン'
      assert_false(@parser.too_long?)

      @parser.body = '0' * NoteParser.max_length
      assert_false(@parser.too_long?)

      @parser.body = '0' * (NoteParser.max_length + 1)
      assert(@parser.too_long?)
    end
  end
end
