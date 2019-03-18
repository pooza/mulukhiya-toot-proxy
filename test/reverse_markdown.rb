module MulukhiyaTootProxy
  class ReverseMarkdownTest < Test::Unit::TestCase
    def test_convert
      assert_equal(ReverseMarkdown.convert('```hoge =&gt; gebo<br />aaa =&gt; bbb<br />```'), "```hoge => gebo \n aaa => bbb \n```")
      assert_equal(ReverseMarkdown.convert('[#aaa]'), "[\\#aaa]\n\n")
    end
  end
end
