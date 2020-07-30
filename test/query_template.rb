module Mulukhiya
  class QueryTemplateTest < TestCase
    def test_escape
      assert_equal(QueryTemplate.escape(%('終わり'なき"混沌"デウスマスト)), %(''終わり''なき"混沌"デウスマスト))
    end
  end
end
