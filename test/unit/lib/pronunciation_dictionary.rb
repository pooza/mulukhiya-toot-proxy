module Mulukhiya
  class PronunciationDictionaryTest < TestCase
    ENTRIES = [
      {'surface' => '愛崎えみる', 'reading' => 'アイサキエミル', 'category' => '人名'},
      {'surface' => '閃華裂光拳', 'reading' => 'センカレッコウケン', 'category' => '技名'},
      {'surface' => 'アイス', 'reading' => 'アイス'},
    ].freeze

    def disable?
      PronunciationDictionary.new.redis.get('1')
      return super
    rescue
      return true
    end

    def setup
      return if disable?
      @dic = PronunciationDictionary.new
      @dic.redis[PronunciationDictionary::REDIS_KEY] = ENTRIES.to_json
    end

    def teardown
      @dic&.invalidate_cache
    end

    def test_suggest_by_hiragana_reading
      results = @dic.suggest('あいさき')

      assert_equal('愛崎えみる', results.first[:surface])
      assert_equal('アイサキエミル', results.first[:reading])
      assert_equal('人名', results.first[:category])
    end

    def test_suggest_passes_category_only_when_present
      entry = @dic.suggest('あいす').find {|r| r[:surface] == 'アイス'}

      assert_not_nil(entry)
      assert_false(entry.key?(:category))
    end

    def test_suggest_reading_prefix_match
      surfaces = @dic.suggest('あい').map {|r| r[:surface]}

      assert_includes(surfaces, '愛崎えみる')
      assert_includes(surfaces, 'アイス')
    end

    def test_suggest_empty_query_returns_empty
      assert_empty(@dic.suggest(''))
    end

    def test_suggest_respects_limit
      assert_operator(@dic.suggest('あい', limit: 1).size, :<=, 1)
    end

    def test_suggest_no_match_returns_empty
      assert_empty(@dic.suggest('ぞんざいしないよみ'))
    end
  end
end
