module Mulukhiya
  class DictionaryTagHandler < TagHandler
    def disable?
      return true unless RemoteDictionary.all.present?
      return super
    end

    def addition_tags
      return TaggingDictionary.new.matches(flatten_payload)
    end
  end
end
