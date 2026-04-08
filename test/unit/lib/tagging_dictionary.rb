module Mulukhiya
  class TaggingDictionaryTest < TestCase
    def disable?
      config['/handler/dictionary_tag/word/min'] = 3
      config['/handler/dictionary_tag/word/min_kanji'] = 2
      TaggingDictionary.new.short?('test')
      return super
    rescue
      return true
    end

    def setup
      return if disable?
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

    def test_strict_key?
      # strict辞書由来のキー（絵文字ショートコード名）は除外対象
      assert(@dic.strict_key?('maam_g')) if @dic.key?('maam_g')

      # 通常辞書のキー（wordsに自身を含む）は除外しない
      assert_false(@dic.strict_key?('キュアマーメイド')) if @dic.key?('キュアマーメイド')

      # 辞書に存在しないキーは除外しない
      assert_false(@dic.strict_key?('存在しないキー12345'))
    end
  end
end
