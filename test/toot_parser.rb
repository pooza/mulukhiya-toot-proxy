module MulukhiyaTootProxy
  class TootParserTest < TestCase
    def setup
      @parser = TootParser.new
    end

    def test_too_long?
      @parser.body = 'ローリン♪ローリン♪ココロにズッキュン'
      assert_false(@parser.too_long?)

      @parser.body = '0' * TootParser.max_length
      assert_false(@parser.too_long?)

      @parser.body = '0' * (TootParser.max_length + 1)
      assert(@parser.too_long?)
    end

    def test_accts
      @parser.body = '@pooza @poozZa @pooza@mstdn.example.com pooza@b-shock.org'
      assert_equal(@parser.accts, ['@pooza', '@poozZa', '@pooza@mstdn.example.com'])
    end
  end
end
