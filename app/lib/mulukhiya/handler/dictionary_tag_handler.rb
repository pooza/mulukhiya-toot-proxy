module Mulukhiya
  class DictionaryTagHandler < TagHandler
    def disable?
      return true unless TaggingDictionary.new.remote_dics.present?
      return super
    end

    def addition_tags
      return TaggingDictionary.new.matches(payload)
    end
  end
end
