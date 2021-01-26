module Mulukhiya
  class TaggingDictionaryTest < TestCase
    def setup
      @dic = TaggingDictionary.new
    end

    def test_exist?
      @dic.delete
      assert_false(@dic.exist?)
      @dic.refresh
      assert(@dic.exist?)
    end

    def test_remote_dics
      @dic.remote_dics do |d|
        assert_kind_of(RemoteDictionary, d)
      end
    end

    def test_short?
      assert(TaggingDictionary.short?('ココ'))
      assert_false(TaggingDictionary.short?('館長'))
    end
  end
end
