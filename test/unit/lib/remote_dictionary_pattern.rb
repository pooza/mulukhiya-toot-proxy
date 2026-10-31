module Mulukhiya
  # 辞書の語から作る正規表現 (#4854)。取得はしないので、外へは出ない。
  class RemoteDictionaryPatternTest < TestCase
    def setup
      @dic = RemoteDictionary.create('url' => 'https://example.jp/api/dic/v1/a.json', 'type' => 'related')
    end

    # 規則の版を上げたら、last-good の鍵も変わること。
    def test_cache_signature_follows_pattern_version
      before = @dic.cache_signature
      version = RemoteDictionary::PATTERN_VERSION
      RemoteDictionary.send(:remove_const, :PATTERN_VERSION)
      RemoteDictionary.const_set(:PATTERN_VERSION, version + 1)

      assert_not_equal(before, @dic.cache_signature)
    ensure
      RemoteDictionary.send(:remove_const, :PATTERN_VERSION)
      RemoteDictionary.const_set(:PATTERN_VERSION, version)
    end

    def test_short_katakana_inside_longer_katakana
      assert_no_match(pattern('ニコ'), 'ニコニコ動画で見た')
      assert_no_match(pattern('ラリー'), 'ギャラリーの展示')
      assert_no_match(pattern('シリー'), '新シリーズの発表')
      assert_no_match(pattern('ドライ'), 'ガイドラインを読む')
      assert_no_match(pattern('キング'), 'メタルキングコインを拾った')
      assert_no_match(pattern('テラ'), 'テラスで食べた')
    end

    def test_short_katakana_standing_alone
      assert_match(pattern('ニコ'), 'ニコが出てきた')
      assert_match(pattern('ニコ'), '今日のニコ')
      assert_match(pattern('ラリー'), 'ラリー、がんばれ')
      assert_match(pattern('キング'), '#キング')
    end

    def test_prolonged_sound_after_hiragana
      assert_match(pattern('ニコ'), 'やったーニコ')
      assert_no_match(pattern('ニコ'), 'ラーニコ')
    end

    def test_prolonged_sound_after_word
      assert_no_match(pattern('ニコ'), 'ニコーン')
    end

    def test_longer_word_is_not_guarded
      assert_match(pattern('キュアモ'), 'プリキュアモード')
      assert_match(pattern('キュアアンサー'), 'キュアアンサーグリーティング')
    end

    def test_non_katakana_word_is_not_guarded
      assert_match(pattern('ほのか'), 'ほのかちゃん')
      assert_match(pattern('ほのか'), 'ホノカほのかホノカ')
      assert_match(pattern('小林'), 'コバヤシ小林コバヤシ')
    end

    def test_guard_only_on_katakana_side
      assert_match(pattern('ゆうキ'), 'ゆうキ')
      assert_match(pattern('ゆうキ'), 'ハゆうキ')
      assert_no_match(pattern('ゆうキ'), 'ゆうキャンプ')
    end

    def test_small_kana_still_folded
      assert_match(pattern('ユメ'), 'ュメの話')
      assert_no_match(pattern('ユメ'), 'ユメミール')
    end

    def test_regexp_source_matches_pattern
      entry = @dic.send(:create_entry, 'ニコ')

      assert_equal(entry[:pattern].source, entry[:regexp])
      assert_false('ニコニコ'.match?(entry[:regexp]))
      assert_true('ニコです'.match?(entry[:regexp]))
    end

    private

    def pattern(word)
      return @dic.send(:create_pattern, word)
    end
  end
end
