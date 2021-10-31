module Mulukhiya
  class DictionaryTagHandler < TagHandler
    def addition_tags
      return TaggingDictionary.new.matches(payload)
    end
  end
end
