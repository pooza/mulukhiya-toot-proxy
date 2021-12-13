module Mulukhiya
  class DictionaryTagHandler < TagHandler
    def disable?
      return true unless RemoteDictionary.all.present?
      return super
    end

    def addition_tags
      return TaggingDictionary.new.matches(flatten_payload)
    end

    def all(&block)
      return enum_for(__method__) unless block
      handler_config(:dics).each(&block)
    end

    def without_kanji_pattern
      return handler_config('word/without_kanji_pattern')
    end

    def minimum_length
      return handler_config('word/min')
    end

    def minimum_length_kanji
      return handler_config('word/min_kanji')
    end
  end
end
