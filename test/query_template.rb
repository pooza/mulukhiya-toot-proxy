module Mulukhiya
  class QueryTemplateTest < TestCase
    def test_escape
      assert_equal(%(''終わり''なき"混沌"デウスマスト), QueryTemplate.escape(%('終わり'なき"混沌"デウスマスト)))
    end
  end
end
