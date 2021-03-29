module Mulukhiya
  class TaggingDictionaryTest < TestCase
    def setup
      config['/tagging/word/minimum_length'] = 3
      @dic = TaggingDictionary.new
    end

    def test_remote_dics
      @dic.remote_dics do |d|
        assert_kind_of(RemoteDictionary, d)
      end
    end

    def test_short?
      assert(TaggingDictionary.short?('ココ'))
      assert_false(TaggingDictionary.short?('館長'))
      assert_false(TaggingDictionary.short?('DX3'))
    end
  end
end
