module Mulukhiya
  class DictionaryTagHandler < TagHandler
    def additional_tags
      return TaggingDictionary.new.matches(payload)
    end
  end
end
