module Mulukhiya
  class TagSearchServiceTest < TestCase
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
      @service = TagSearchService.new
    end

    def test_search_returns_hash
      return if disable?
      results = @service.search(SecureRandom.hex(32))

      assert_kind_of(Hash, results)
      assert_empty(results)
    end
  end
end
