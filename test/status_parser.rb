module Mulukhiya
  class StatusParserTest < TestCase
    def setup
      @parser = Environment.parser_class.new
    end

    def test_body
      @parser.text = 'ローリン♪ローリン♪ココロにズッキュン'
      assert_equal(@parser.text, 'ローリン♪ローリン♪ココロにズッキュン')
      assert_equal(@parser.to_s, 'ローリン♪ローリン♪ココロにズッキュン')
    end

    def test_length
      @parser.text = 'ローリン♪ローリン♪ココロにズッキュン'
      assert_equal(@parser.length, 19)
    end

    def test_exec
      @parser.text = 'ローリン♪ローリン♪ココロにズッキュン'
      assert_nil(@parser.exec)
      assert_nil(@parser.command_name)
      assert_false(@parser.command?)

      @parser.text = "command: command1\nfoo: bar"
      assert_equal(@parser.exec, {'command' => 'command1', 'foo' => 'bar'})
      assert_equal(@parser.command_name, 'command1')
      assert(@parser.command?)

      @parser.text = '{"command": "command2", "bar": "buz"}'
      assert_equal(@parser.exec, {'command' => 'command2', 'bar' => 'buz'})
      assert_equal(@parser.command_name, 'command2')
      assert(@parser.command?)
    end

    def test_hashtags
      @parser.text = 'pooza@b-shock.org'
      assert_equal(@parser.hashtags, [])

      @parser.text = '#aaa #bbbb @pooza @pooza@precure.ml よろです。'
      assert_equal(@parser.hashtags, ['aaa', 'bbbb'])
    end

    def test_to_sanitized
      @parser.text = '<p>hoge<br>hoge</p><p>hoge<br>hoge</p>'
      assert_equal(@parser.to_sanitized, "hoge\nhoge\n\n  hoge\nhoge")
    end

    def test_accts
      @parser.text = '#hoge'
      assert_equal(@parser.accts.to_a, [])

      @parser.text = '@pooza @pooza@precure.ml よろです。 pooza@b-shock.org'
      @parser.accts do |acct|
        assert_kind_of(Acct, acct)
        assert(acct.valid?)
      end
      assert_equal(@parser.accts.map(&:to_s), ['@pooza', '@pooza@precure.ml'])
    end
  end
end
