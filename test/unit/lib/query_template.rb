module Mulukhiya
  class QueryTemplateTest < TestCase
    def disable?
      return true unless Environment.postgres?
      return true unless Postgres.config?
      return super
    end

    def test_escape
      assert_equal(%(''終わり''なき"混沌"デウスマスト), QueryTemplate.escape(%('終わり'なき"混沌"デウスマスト)))
    end
  end
end
