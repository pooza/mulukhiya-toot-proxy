module Mulukhiya
  class SearchRuleTest < TestCase
    def setup
      @rule = SearchRule.new('ゆいぴょん ここぴー らんらん -マリっぺ')
    end

    def test_text
      assert_equal('ゆいぴょん ここぴー らんらん -マリっぺ', @rule.text)
    end

    def test_keywords
      assert_equal(Set['ゆいぴょん', 'ここぴー', 'らんらん'], @rule.keywords)
    end

    def test_negative_keywords
      assert_equal(Set['マリっぺ'], @rule.negative_keywords)
    end
  end
end
