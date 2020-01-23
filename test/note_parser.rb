module Mulukhiya
  class NoteParserTest < TestCase
    def setup
      @parser = NoteParser.new
    end

    def test_too_long?
      @parser.body = 'ローリン♪ローリン♪ココロにズッキュン'
      assert_false(@parser.too_long?)

      @parser.body = '0' * @parser.max_length
      assert_false(@parser.too_long?)

      @parser.body = '0' * (@parser.max_length + 1)
      assert(@parser.too_long?)
    end

    def test_accts
      @parser.body = '@pooza @poozZa @pooza@mstdn.example.com pooza@b-shock.org'
      assert_equal(@parser.accts.to_a, ['@pooza', '@poozZa', '@pooza@mstdn.example.com'])
    end

    def test_uris
      @parser.body = 'https://www.google.co.jp https://mstdn.b-shock.co.jp'
      assert_equal(@parser.uris.to_a.map(&:to_s), ['https://www.google.co.jp', 'https://mstdn.b-shock.co.jp'])
    end
  end
end
