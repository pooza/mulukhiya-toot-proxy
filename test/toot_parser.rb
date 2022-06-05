module Mulukhiya
  class TootParserTest < TestCase
    def disable?
      return true unless Environment.toot?
      return super
    end

    def setup
      @parser = TootParser.new('さぁデリシャススマイル・フルパワーで')
    end

    def test_default_max_length
      assert_kind_of(Integer, @parser.default_max_length)
    end
  end
end
