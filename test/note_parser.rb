module Mulukhiya
  class NoteParserTest < TestCase
    def setup
      @parser = NoteParser.new
      @config = Config.instance
      @config['/dolphin/url'] = 'https://dol.example.com/'
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
      assert_equal(@parser.accts, ['@pooza', '@poozZa', '@pooza@mstdn.example.com'])
    end

    def test_to_md
      @parser.body = '@pooza @poozZa @pooza@mstdn.example.com pooza@b-shock.org'
      assert_equal(@parser.to_md, '[@pooza](https://dol.example.com/@pooza) [@poozZa](https://dol.example.com/@poozZa) [@pooza@mstdn.example.com](https://dol.example.com/@pooza@mstdn.example.com) pooza@b-shock.org')
    end
  end
end
