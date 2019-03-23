module MulukhiyaTootProxy
  class TaggingDictionaryTest < Test::Unit::TestCase
    def setup
      @dic = TaggingDictionary.instance
    end

    def test_exist?
      @dic.delete
      assert_false(@dic.exist?)
      @dic.refresh
      assert(@dic.exist?)
    end
  end
end
