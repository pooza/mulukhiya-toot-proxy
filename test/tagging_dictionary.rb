module Mulukhiya
  class TaggingDictionaryTest < TestCase
    def setup
      config['/handler/dictionary_tag/word/min'] = 3
      config['/handler/dictionary_tag/word/min_kanji'] = 2
      @dic = TaggingDictionary.new
    end

    def test_short?
      assert(TaggingDictionary.short?('ココ'))
      assert(TaggingDictionary.short?('中'))
      assert_false(TaggingDictionary.short?('館長'))
      assert_false(TaggingDictionary.short?('DX3'))
      assert_false(TaggingDictionary.short?('速水'))
      assert_false(TaggingDictionary.short?('宇宙大魔王'))
    end
  end
end
