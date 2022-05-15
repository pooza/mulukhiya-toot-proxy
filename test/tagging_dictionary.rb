module Mulukhiya
  class TaggingDictionaryTest < TestCase
    def disable?
      return true if Environment.ci?
      return super
    end

    def setup
      config['/handler/dictionary_tag/word/min'] = 3
      config['/handler/dictionary_tag/word/min_kanji'] = 2
      @dic = TaggingDictionary.new
    end

    def test_short?
      assert(@dic.short?('ココ'))
      assert(@dic.short?('中'))
      assert_false(@dic.short?('館長'))
      assert_false(@dic.short?('DX3'))
      assert_false(@dic.short?('速水'))
      assert_false(@dic.short?('宇宙大魔王'))
    end
  end
end
