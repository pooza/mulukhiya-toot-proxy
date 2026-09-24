module Mulukhiya
  # タグ辞書の照合順序 (#4463) の回帰テスト。
  #
  # ⚠ **TaggingDictionaryTest と分けてあるのは、あちらが辞書ソースの設定を前提に
  # するから。**CI には辞書ソースが無いので、あちらはクラスごと omission になる。
  # 照合に要るのは語の長さの閾値だけなので、それを返すダブルを差し込んで常に実走させる
  # （TaggingDictionaryCacheTest と同じ形。#4503）。
  class TaggingDictionaryMatchTest < TestCase
    HandlerDouble = Struct.new(:without_kanji_pattern, :minimum_length, :minimum_length_kanji)

    def setup
      @dic = TaggingDictionary.allocate
      @dic.instance_variable_set(:@handler, HandlerDouble.new('[0-9a-zA-Zあ-んア-ン]', 3, 2))
    end

    # 長い語が先に当たり、当たった語は本文から消し込まれる。
    # ⚠ 並列に回していた頃は、この順序がスレッドの進み具合次第だった。
    def test_longer_word_is_consumed_first
      @dic.replace(
        'ブラック' => {pattern: /ブラック/, words: ['ブラック']},
        'キュアブラック' => {pattern: /キュアブラック/, words: ['キュアブラック', '美墨 なぎさ']},
      )

      assert_equal(['キュアブラック', '美墨 なぎさ'], @dic.match_words('キュアブラック！'))
      assert_equal(
        ['キュアブラック', '美墨 なぎさ', 'ブラック'],
        @dic.match_words('キュアブラック と ブラックサンダー'),
      )
    end

    # 辞書の並びが長さ順でなくても、長い語から照合する。
    def test_order_does_not_depend_on_key_order
      @dic.replace(
        'キュアブラック' => {pattern: /キュアブラック/, words: ['キュアブラック']},
        'ブラック' => {pattern: /ブラック/, words: ['ブラック']},
      )

      assert_equal(['キュアブラック'], @dic.match_words('キュアブラック！'))
    end

    def test_short_word_is_skipped
      @dic.replace(
        'ココ' => {pattern: /ココ/, words: ['ココ']},
        '中' => {pattern: /中/, words: ['中']},
      )

      assert_empty(@dic.match_words('ココは中です'))
    end

    def test_short?
      assert(@dic.short?('ココ'))
      assert(@dic.short?('中'))
      assert_false(@dic.short?('館長'))
      assert_false(@dic.short?('DX3'))
      assert_false(@dic.short?('宇宙大魔王'))
    end
  end
end
