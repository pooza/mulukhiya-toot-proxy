module Mulukhiya
  class SearchKeywordParserTest < TestCase
    def setup
      @parser = SearchKeywordParser.new('ゆいぴょん ここぴー らんらん -マリっぺ')
    end

    def test_keywords
      assert_equal(Set['ゆいぴょん', 'ここぴー', 'らんらん'], @parser.keywords)
    end

    def test_negative_keywords
      assert_equal(Set['マリっぺ'], @parser.negative_keywords)
    end
  end
end
